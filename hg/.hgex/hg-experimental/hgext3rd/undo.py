# undo.py: records data in revlog for future undo functionality
#
# Copyright 2017 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from __future__ import absolute_import

import os

from mercurial.i18n import _

from mercurial import (
    cmdutil,
    commands,
    dispatch,
    error,
    extensions,
    fancyopts,
    hg,
    localrepo,
    lock as lockmod,
    obsolete,
    obsutil,
    phases,
    registrar,
    revlog,
    revset,
    revsetlang,
    smartset,
    templatekw,
    templater,
    transaction,
    util,
)

from mercurial.node import (
    bin,
    hex,
    nullid,
)

cmdtable = {}
command = registrar.command(cmdtable)

# Setup

def extsetup(ui):
    extensions.wrapfunction(dispatch, 'runcommand', _runcommandwrapper)

    # undo has its own locking, whitelist itself to bypass repo lock audit
    localrepo.localrepository._wlockfreeprefix.add('undolog/')

# Wrappers

def _runcommandwrapper(orig, lui, repo, cmd, fullargs, *args):
    # This wrapper executes whenever a command is run.
    # Some commands (eg hg sl) don't actually modify anything
    # ie can't be undone, but the command doesn't know this.
    command = fullargs

    # Check wether undolog is consistent
    # ie check wether the undo ext was
    # off before this command
    if '_undologactive' not in os.environ:
        changes = safelog(repo, [""])
        if changes:
            _recordnewgap(repo)

    # prevent nested calls
    if '_undologactive' not in os.environ:
        os.environ['_undologactive'] = "active"
        rootlog = True
    else:
        rootlog = False

    result = orig(lui, repo, cmd, fullargs, *args)

    # record changes to repo
    if rootlog:
        safelog(repo, command)
        del os.environ['_undologactive']
    return result

# Write: Log control

def safelog(repo, command):
    '''boilerplate for log command

    input:
        repo: mercurial.localrepo
        command: list of strings, first is string of command run
    output: bool
        True if changes have been recorded, False otherwise
    '''
    changes = False
    if repo is not None: # some hg commands don't require repo
        # undolog specific lock
        # allows running command during other commands when
        # otherwise legal.  Could cause weird undolog states,
        # which gap handling generally covers.
        try:
            try:
                repo.vfs.makedirs('undolog')
            except OSError:
                repo.ui.debug("can't make undolog folder in .hg\n")
                return changes
            with lockmod.lock(repo.vfs, "undolog/lock", desc="undolog",
                              timeout=2):
                # developer config: undo._duringundologlock
                if repo.ui.configbool('undo', '_duringundologlock'):
                    repo.hook("duringundologlock")
                tr = lighttransaction(repo)
                with tr:
                    changes = log(repo.filtered('visible'), command, tr)
                    if changes and not ("undo" == command[0] or "redo" ==
                                        command[0]):
                        _delundoredo(repo)
        except error.LockUnavailable: # no write permissions
            repo.ui.debug("undolog lacks write permission\n")
        except error.LockHeld: # timeout, not fatal: don't abort actual command
            # TODO: log to Scuba.  This shouldn't happen too often as it will
            # create gaps in the undo log
            repo.ui.debug("undolog lock timeout\n")
    return changes

def lighttransaction(repo):
    # full fledged transactions have two serious issues:
    # 1. they may cause infite loops through hooks
    #    that run commands
    # 2. they are really expensive performance wise
    #
    # ligtthransaction avoids certain hooks from being
    # executed, doesn't check repo locks, doesn't check
    # abandoned tr's (since we only record info) and doesn't
    # do any tag handling
    vfsmap = {'plain': repo.vfs}
    tr = transaction.transaction(repo.ui.warn, repo.vfs, vfsmap,
                                 "undolog/tr.journal", "undolog/tr.undo")
    return tr

def log(repo, command, tr):
    '''logs data neccesary for undo if repo state has changed

    input:
        repo: mercurial.localrepo
        command: los, first is command to be recorded as run
        tr: transaction
    output: bool
        True if changes recorded
        False if no changes to record
    '''
    newnodes = {
        'bookmarks': _logbookmarks(repo, tr),
        'draftheads': _logdraftheads(repo, tr),
        'workingparent': _logworkingparent(repo, tr),
    }
    try:
        existingnodes = _readindex(repo, 0)
    except IndexError:
        existingnodes = {}
    if all(newnodes.get(x) == existingnodes.get(x) for x in newnodes.keys()):
        # no changes to record
        return False
    else:
        newnodes.update({
            'date': _logdate(repo, tr),
            'command': _logcommand(repo, tr, command),
        })
        _logindex(repo, tr, newnodes)
        # changes have been recorded
        return True

# Write: Logs

def writelog(repo, tr, name, revstring):
    if tr is None:
        raise error.ProgrammingError
    rlog = _getrevlog(repo, name)
    node = rlog.addrevision(revstring, tr, 1, nullid, nullid)
    return hex(node)

def _logdate(repo, tr):
    revstring = " ".join(str(x) for x in util.makedate())
    return writelog(repo, tr, "date.i", revstring)

def _logdraftheads(repo, tr):
    spec = revsetlang.formatspec('heads(draft())')
    hexnodes = tohexnode(repo, spec)
    revstring = "\n".join(sorted(hexnodes))
    return writelog(repo, tr, "draftheads.i", revstring)

def _logcommand(repo, tr, command):
    revstring = "\0".join(command)
    return writelog(repo, tr, "command.i", revstring)

def _logbookmarks(repo, tr):
    revstring = "\n".join(sorted('%s %s' % (name, hex(node))
        for name, node in repo._bookmarks.iteritems()))
    return writelog(repo, tr, "bookmarks.i", revstring)

def _logworkingparent(repo, tr):
    revstring = repo['.'].hex()
    return writelog(repo, tr, "workingparent.i", revstring)

def _logindex(repo, tr, nodes):
    revstring = "\n".join(sorted('%s %s' % (k, v) for k, v in nodes.items()))
    return writelog(repo, tr, "index.i", revstring)

def _logundoredoindex(repo, reverseindex, branch=""):
    rlog = _getrevlog(repo, 'index.i')
    hexnode = hex(rlog.node(_invertindex(rlog, reverseindex)))
    return repo.vfs.write("undolog/redonode", str(hexnode) + "\0" + branch)

def _delundoredo(repo):
    path = 'undolog' + '/' + 'redonode'
    repo.vfs.tryunlink(path)

def _recordnewgap(repo, absoluteindex=None):
    path = 'undolog' + '/' + 'gap'
    if absoluteindex is None:
        rlog = _getrevlog(repo, 'index.i')
        repo.vfs.write(path, str(len(rlog) - 1))
    else:
        repo.vfs.write(path, str(absoluteindex))

# Read

def _readindex(repo, reverseindex, prefetchedrevlog=None):
    if prefetchedrevlog is None:
        rlog = _getrevlog(repo, 'index.i')
    else:
        rlog = prefetchedrevlog
    index = _invertindex(rlog, reverseindex)
    if index < 0 or index > len(rlog) - 1:
        raise IndexError
    chunk = rlog.revision(index)
    indexdict = {}
    for row in chunk.split("\n"):
        kvpair = row.split(' ', 1)
        if kvpair[0]:
            indexdict[kvpair[0]] = kvpair[1]
    return indexdict

def _readnode(repo, filename, hexnode):
    rlog = _getrevlog(repo, filename)
    return rlog.revision(bin(hexnode))

def _gapcheck(repo, reverseindex):
    rlog = _getrevlog(repo, 'index.i')
    absoluteindex = _invertindex(rlog, reverseindex)
    path = 'undolog' + '/' + 'gap'
    try:
        result = absoluteindex >= int(repo.vfs.read(path))
    except IOError:
        # recreate file
        repo.ui.debug("failed to read gap file in %s, attempting recreation\n"
                      % path)
        rlog = _getrevlog(repo, 'index.i')
        i = 0
        while i < (len(rlog)):
            indexdict = _readindex(repo, i, rlog)
            if "" == _readnode(repo, "command.i", indexdict["command"]):
                break
            i += 1
        # defaults to before oldest command
        _recordnewgap(repo, _invertindex(rlog, i))
        result = absoluteindex >= _invertindex(rlog, i)
    finally:
        return result

# Visualize

"""debug commands and instrumentation for the undo extension

Adds the `debugundohistory` and `debugundosmartlog` commands to visualize
operational history and to give a preview of how undo will behave.
"""

@command('debugundohistory', [
    ('n', 'index', 0, _("details about specific operation")),
    ('l', 'list', False, _("list recent undo-able operation"))
])
def debugundohistory(ui, repo, *args, **opts):
    """ Print operational history
        0 is the most recent operation
    """
    if repo is not None:
        if opts.get('list'):
            if args and args[0].isdigit():
                offset = int(args[0])
            else:
                offset = 0
            _debugundolist(ui, repo, offset)
        else:
            reverseindex = opts.get('index')
            if 0 == reverseindex and args and args[0].isdigit():
                reverseindex = int(args[0])
            _debugundoindex(ui, repo, reverseindex)

def _debugundolist(ui, repo, offset):
    offset = abs(offset)

    template = "{sub('\0', ' ', undo)}\n"
    fm = ui.formatter('debugundohistory', {'template': template})
    prefetchedrevlog = _getrevlog(repo, 'index.i')
    recentrange = min(5, len(prefetchedrevlog) - offset)
    if 0 == recentrange:
        fm.startitem()
        fm.write('undo', '%s', "None")
    for i in range(recentrange):
        nodedict = _readindex(repo, i + offset, prefetchedrevlog)
        commandstr = _readnode(repo, 'command.i', nodedict['command'])
        if "" == commandstr:
            commandstr = " -- gap in log -- "
        fm.startitem()
        fm.write('undo', '%s', str(i + offset) + ": " + commandstr)
    fm.end()

def _debugundoindex(ui, repo, reverseindex):
    try:
        nodedict = _readindex(repo, reverseindex)
    except IndexError:
        raise error.Abort(_("index out of bounds"))
        return
    template = "{tabindent(sub('\0', ' ', content))}\n"
    fm = ui.formatter('debugundohistory', {'template': template})
    cabinet = ('command.i', 'bookmarks.i', 'date.i',
            'draftheads.i', 'workingparent.i')
    for filename in cabinet:
        header = filename[:-2] + ":\n"
        rawcontent = _readnode(repo, filename, nodedict[filename[:-2]])
        if "date.i" == filename:
            splitdate = rawcontent.split(" ")
            datetuple = (float(splitdate[0]), int(splitdate[1]))
            content = util.datestr(datetuple)
        elif "draftheads.i" == filename:
            try:
                oldnodes = _readindex(repo, reverseindex + 1)
                oldheads = _readnode(repo, filename, oldnodes[filename[:-2]])
            except IndexError: # index is oldest log
                content = rawcontent
            else:
                content = "ADDED:\n\t" + "\n\t".join(sorted(
                        set(rawcontent.split("\n"))
                        - set(oldheads.split("\n"))
                        ))
                content += "\nREMOVED:\n\t" + "\n\t".join(sorted(
                        set(oldheads.split("\n"))
                        - set(rawcontent.split("\n"))
                        ))
        elif "command.i" == filename and "" == rawcontent:
            content = "unkown command(s) run, gap in log"
        else:
            content = rawcontent
        fm.startitem()
        fm.write('content', '%s', header + content)
    fm.end()

# Revset logic

def _getolddrafts(repo, reverseindex):
    nodedict = _readindex(repo, reverseindex)
    olddraftheads = _readnode(repo, "draftheads.i", nodedict["draftheads"])
    oldheadslist = olddraftheads.split("\n")
    oldlogrevstring = revsetlang.formatspec('draft() & ancestors(%ls)',
            oldheadslist)
    urepo = repo.unfiltered()
    return urepo.revs(oldlogrevstring)

revsetpredicate = registrar.revsetpredicate()

@revsetpredicate('olddraft')
def _olddraft(repo, subset, x):
    """``olddraft([index])``
    previous draft commits

    'index' is how many undoable commands you want to look back
    an undoable command is one that changed draft heads, bookmarks
    and or working copy parent.  Note that olddraft uses an absolute index and
    so olddraft(1) represents the state after an hg undo -a and not an hg undo.
    Note: this revset may include hidden commits
    """
    args = revset.getargsdict(x, 'olddraftrevset', 'reverseindex')
    reverseindex = revsetlang.getinteger(args.get('reverseindex'),
                _('index must be a positive integer'), 1)
    revs = _getolddrafts(repo, reverseindex)
    return subset & smartset.baseset(revs)

@revsetpredicate('_localbranch')
def _localbranch(repo, subset, x):
    """``_localbranch(changectx)``
    localbranch changesets

    Returns all commits within the same localbranch as the changeset(s). A local
    branch is all draft changesets that are connected, uninterupted by public
    changesets.  Any draft commit within a branch, or a public commit at the
    base of the branch, can be passed used to identify localbranches.
    """
    # executed on an filtered repo
    args = revset.getargsdict(x, 'branchrevset', 'changectx')
    revstring = revsetlang.getstring(args.get('changectx'),
                               _('localbranch argument must be a changectx'))
    revs = repo.revs(revstring)
    # we assume that there is only a single rev
    if repo[revs.first()].phase() == phases.public:
        querystring = revsetlang.formatspec('(children(%d) & draft())::',
                                            revs.first())
    else:
        querystring = revsetlang.formatspec('((::%ld) & draft())::', revs)
    return subset & smartset.baseset(repo.revs(querystring))

# Templates
templatefunc = registrar.templatefunc()

def _undonehexnodes(repo, reverseindex):
    repo = repo.unfiltered()
    revstring = revsetlang.formatspec('draft() - olddraft(%d)', reverseindex)
    revs = repo.revs(revstring)
    tonode = repo.changelog.node
    hexnodes = [repo[tonode(x)] for x in revs]
    return hexnodes

@templatefunc('undonecommits(reverseindex)')
def showundonecommits(context, mapping, args):
    """String.  Changectxs added since reverseindex command."""
    reverseindex = templater.evalinteger(context, mapping, args[0],
                                _('undonecommits needs an integer argument'))
    repo = mapping['ctx']._repo
    ctx = mapping['ctx']
    hexnodes = _undonehexnodes(repo, reverseindex)
    if ctx in hexnodes:
        result = ctx.hex()
    else:
        result = None
    return result

def _donehexnodes(repo, reverseindex):
    repo = repo.unfiltered()
    revstring = revsetlang.formatspec('olddraft(%d)', reverseindex)
    revs = repo.revs(revstring)
    tonode = repo.changelog.node
    hexnodes = [repo[tonode(x)] for x in revs]
    return hexnodes

@templatefunc('donecommits(reverseindex)')
def showdonecommits(context, mapping, args):
    """String.  Changectxs reverseindex repo states ago."""
    reverseindex = templater.evalinteger(context, mapping, args[0],
                                    _('donecommits needs an integer argument'))
    repo = mapping['ctx']._repo
    ctx = mapping['ctx']
    hexnodes = _donehexnodes(repo, reverseindex)
    if ctx in hexnodes:
        result = ctx.hex()
    else:
        result = None
    return result

def _oldmarks(repo, reverseindex):
    nodedict = _readindex(repo, reverseindex)
    bookstring = _readnode(repo, "bookmarks.i", nodedict["bookmarks"])
    oldmarks = bookstring.split("\n")
    result = []
    for mark in oldmarks:
        kv = mark.rsplit(" ", 1)
        if len(kv) == 2:
            result.append(kv)
    return result

@templatefunc('oldbookmarks(reverseindex)')
def showoldbookmarks(context, mapping, args):
    """List of Strings. Bookmarks that used to be at the changectx reverseindex
    repo states ago."""
    reverseindex = templater.evalinteger(context, mapping, args[0],
                                    _('oldbookmarks needs an integer argument'))
    repo = mapping['ctx']._repo
    ctx = mapping['ctx']
    oldmarks = _oldmarks(repo, reverseindex)
    bookmarks = []
    for kv in oldmarks:
        if repo[kv[1]] == repo[ctx]:
            bookmarks.append(kv[0])
    active = repo._activebookmark
    makemap = lambda v: {'bookmark': v, 'active': active, 'current': active}
    f = templatekw._showlist('bookmark', bookmarks, mapping)
    return templatekw._hybrid(f, bookmarks, makemap, lambda x: x['bookmark'])

@templatefunc('removedbookmarks(reverseindex)')
def removedbookmarks(context, mapping, args):
    """List of Strings.  Bookmarks that have been moved or removed from a given
    changectx by reverseindex repo state."""
    reverseindex = templater.evalinteger(context, mapping, args[0],
                                _('removedbookmarks needs an integer argument'))
    repo = mapping['ctx']._repo
    ctx = mapping['ctx']
    currentbookmarks = mapping['ctx'].bookmarks()
    oldmarks = _oldmarks(repo, reverseindex)
    oldbookmarks = []
    for kv in oldmarks:
        if repo[kv[1]] == repo[ctx]:
            oldbookmarks.append(kv[0])
    bookmarks = list(set(currentbookmarks) - set(oldbookmarks))
    active = repo._activebookmark
    makemap = lambda v: {'bookmark': v, 'active': active, 'current': active}
    f = templatekw._showlist('bookmark', bookmarks, mapping)
    return templatekw._hybrid(f, bookmarks, makemap, lambda x: x['bookmark'])

# Undo:

@command('undo', [
    ('a', 'absolute', False, _("absolute based on command index instead of "
                               "relative undo")),
    ('b', 'branch', "", _("local branch undo, accepts commit hash "
                          "(ADVANCED)")),
    ('f', 'force', False, _("undo across missing undo history (ADVANCED)")),
    ('i', 'interactive', False, _("use interactive ui for undo")),
    ('k', 'keep', False, _("keep working copy changes")),
    ('n', 'step', 1, _("how many steps to undo back")),
    ('p', 'preview', False, _("see smartlog like preview of future undo "
                              "state")),
])
def undo(ui, repo, *args, **opts):
    """perform an undo

    Undoes an undoable command.  An undoable command is one that changed at
    least one of the following three: bookmarks, working copy parent or
    changesets. Note that this specifically does not include commands like log.
    It will include update if update changes the working copy parent (you update
    to a changeset that isn't the current one).  Note that commands that edit
    public repos can't be undone (specifically push).

    Undo does not preserve the working copy changes.

    Use hg undo --preview for interactive preview.  Use your left and right
    arrow keys to explore possible states, hit enter to go to a state or q to
    quit out of preview.

    .. container:: verbose

        Without the --absolute flag, your undos will be relative.  This means
        they will behave how you expect them to.  If you run hg undo twice,
        you will move back two repo states from where you ran your first hg
        undo. You can use this in conjunction with `hg undo -n -1` to move up
        and down repo states.  Note that as soon as you execute a different
        undoable command, which isn't hg undo or hg redo, any new undos or redos
        will be relative to the state after this command.

        If the undo extension was turned off and on again, you might loose the
        ability to undo to certain repo states.  Undoing to repo states before
        the missing ones can be forced, but isn't advised unless its known how
        the before and after states are connected.

        Use keep to maintain working copy changes.  With keep, undo mimics hg
        unamend and hg uncommit.  Specifically, files that exist currently that
        don't exist at the repo state we are undoing to will remain in your
        working copy but not in your changeset.  Maintaining your working copy
        has primarily two downsides: firstly your new working copy won't be
        clean so you can't simply redo without cleaning your working copy.
        Secondly, the operation may be slow if your working copy is large.  If
        unsure, its generally easier try undo without --keep first and redo if
        you want to change this.

        Branch limits the scope of an undo to a group of local (draft)
        changectxs, identified by any one member of this group.
    """
    reverseindex = opts.get("step")
    relativeundo = not opts.get("absolute")
    keep = opts.get("keep")
    branch = opts.get("branch")
    preview = opts.get("preview")
    interactive = opts.get("interactive")
    if interactive:
        preview = True

    repo = repo.unfiltered()

    if branch and reverseindex != 1 and reverseindex != -1:
        raise error.Abort(_("--branch with --index not supported"))
    if relativeundo:
        reverseindex = _computerelative(repo, reverseindex,
                                        absolute = not relativeundo,
                                        branch = branch)
    if branch and preview:
        raise error.Abort(_("--branch with --preview not supported"))

    if interactive:
        try:
            interactiveui = extensions.find('interactiveui')
        except KeyError:
            raise error.Abort(_('undo --interactive requires interactiveui to '
                                'work'))
            return

        class undopreview(interactiveui.viewframe):
            def init(self, repo, ui, index):
                self.repo = repo
                self.ui = ui
                self.index = index
            def render(self):
                ui = self.ui
                ui.pushbuffer()
                _preview(ui, self.repo, self.index)
                return ui.popbuffer()
            def rightarrow(self):
                self.index += 1
            def leftarrow(self):
                self.index -= 1
            def enter(self):
                del opts["preview"]
                del opts["interactive"]
                opts["absolute"] = "absolute"
                opts["step"] = self.index
                undo(ui, repo, *args, **opts)
                return
        viewobj = undopreview(ui, repo, reverseindex)
        interactiveui.view(viewobj)
        return
    elif preview:
        _preview(ui, repo, reverseindex)
        return

    with repo.wlock(), repo.lock(), repo.transaction("undo"):
        cmdutil.checkunfinished(repo)
        cmdutil.bailifchanged(repo)
        if not (opts.get("force") or _gapcheck(repo, reverseindex)):
            raise error.Abort(_("attempted risky undo across"
                                " missing history"))
        _undoto(ui, repo, reverseindex, keep=keep, branch=branch)

        # store undo data
        # for absolute undos, think of this as a reset
        # for relative undos, think of this as an update
        _logundoredoindex(repo, reverseindex, branch)

@command('redo', [
    ('p', 'preview', False, _("see smartlog like preview of future redo "
                              "state")),
])
def redo(ui, repo, *args, **opts):
    """ perform a redo

    Rolls back the previous undo.
    """
    shiftedindex = _computerelative(repo, 0)
    preview = opts.get("preview")

    branch = ""
    reverseindex = 0
    redocount = 0
    done = False
    while not done:
        # we step back the linear undo log
        # redoes cancel out undoes, if we have one more undo, we should undo
        # there, otherwise we continue looking
        # we are careful to not redo past absolute undoes (bc we loose undoredo
        # log info)
        # if we run into something that isn't undo or redo, we Abort (including
        # gaps in the log)
        # we extract the --index arguments out of undoes to make sure we update
        # the undoredo index correctly
        nodedict = _readindex(repo, reverseindex)
        commandstr = _readnode(repo, 'command.i', nodedict['command'])
        commandlist = commandstr.split("\0")

        if commandlist[0] == "undo":
            undoopts = {}
            fancyopts.fancyopts(commandlist[1:],
                                cmdtable['undo'][1] + commands.globalopts,
                                undoopts)
            if redocount == 0:
                # want to go to state before the undo (not after)
                toshift = undoopts['step']
                shiftedindex -= toshift
                reverseindex += 1
                branch = undoopts.get('branch')
                done = True
            else:
                if undoopts['absolute']:
                    raise error.Abort(_("can't redo past absolute undo"))
                reverseindex += 1
                redocount -= 1
        elif commandlist[0] == "redo":
            redocount += 1
            reverseindex += 1
        else:
            raise error.Abort(_("nothing to redo"))

    if preview:
        _preview(ui, repo, reverseindex)
        return

    with repo.wlock(), repo.lock(), repo.transaction("redo"):
        cmdutil.checkunfinished(repo)
        cmdutil.bailifchanged(repo)
        repo = repo.unfiltered()
        _undoto(ui, repo, reverseindex)
        # update undredo by removing what the given undo added
        _logundoredoindex(repo, shiftedindex, branch)

def _undoto(ui, repo, reverseindex, keep=False, branch=None):
    # undo to specific reverseindex
    # requires inhibit extension
    # branch is a changectx hash (potentially short form)
    # which identifies its branch via localbranch revset
    if repo != repo.unfiltered():
        raise error.ProgrammingError(_("_undoto expects unfilterd repo"))
    try:
        nodedict = _readindex(repo, reverseindex)
    except IndexError:
        raise error.Abort(_("index out of bounds"))

    # bookmarks
    bookstring = _readnode(repo, "bookmarks.i", nodedict["bookmarks"])
    booklist = bookstring.split("\n")
    if branch:
        spec = revsetlang.formatspec('_localbranch(%s)', branch)
        branchcommits = tohexnode(repo, spec)
    else:
        branchcommits = False

    # copy implementation for bookmarks
    itercopy = []
    for mark in repo._bookmarks.iteritems():
        itercopy.append(mark)
    bmremove = []
    for mark in itercopy:
        if not branchcommits or hex(mark[1]) in branchcommits:
            bmremove.append((mark[0], None))
    repo._bookmarks.applychanges(repo, repo.currenttransaction(), bmremove)
    bmchanges = []
    for mark in booklist:
        if mark:
            kv = mark.rsplit(" ", 1)
            if not branchcommits or\
                kv[1] in branchcommits or\
                (kv[0], None) in bmremove:
                bmchanges.append((kv[0], bin(kv[1])))
    repo._bookmarks.applychanges(repo, repo.currenttransaction(), bmchanges)

    # working copy parent
    workingcopyparent = _readnode(repo, "workingparent.i",
                                  nodedict["workingparent"])
    if not keep:
        if not branchcommits or workingcopyparent in branchcommits:
            hg.updatetotally(ui, repo, workingcopyparent, workingcopyparent,
                             clean=False, updatecheck='abort')
    elif not branchcommits or workingcopyparent in branchcommits:
        # keeps working copy files
        precnode = bin(workingcopyparent)
        precctx = repo[precnode]

        changedfiles = []
        wctx = repo[None]
        wctxmanifest = wctx.manifest()
        precctxmanifest = precctx.manifest()
        dirstate = repo.dirstate
        diff = precctxmanifest.diff(wctxmanifest)
        changedfiles.extend(diff.iterkeys())

        with dirstate.parentchange():
            dirstate.rebuild(precnode, precctxmanifest, changedfiles)
            # we want added and removed files to be shown
            # properly, not with ? and ! prefixes
            for filename, data in diff.iteritems():
                if data[0][0] is None:
                    dirstate.add(filename)
                if data[1][0] is None:
                    dirstate.remove(filename)

    # visible changesets
    addedrevs = revsetlang.formatspec('olddraft(0) - olddraft(%d)',
                                      reverseindex)
    removedrevs = revsetlang.formatspec('olddraft(%d) - olddraft(0)',
                                        reverseindex)
    if not branch:
        smarthide(repo, addedrevs, removedrevs)
        revealcommits(repo, removedrevs)
    else:
        localadds = revsetlang.formatspec('(olddraft(0) - olddraft(%d)) and'
                                          ' _localbranch(%s)',
                                          reverseindex, branch)
        localremoves = revsetlang.formatspec('(olddraft(%d) - olddraft(0)) and'
                                          ' _localbranch(%s)',
                                          reverseindex, branch)
        smarthide(repo, localadds, removedrevs)
        smarthide(repo, addedrevs, localremoves, local=True)
        revealcommits(repo, localremoves)

def _computerelative(repo, reverseindex, absolute=False, branch=""):
    # allows for relative undos using
    # redonode storage
    # allows for branch undos using
    # findnextdelta logic
    if not absolute:
        try: # attempt to get relative shift
            nodebranch = repo.vfs.read("undolog/redonode").split("\0")
            hexnode = nodebranch[0]
            try:
                oldbranch = nodebranch[1]
            except IndexError:
                oldbranch = ""
            rlog = _getrevlog(repo, 'index.i')
            rev = rlog.rev(bin(hexnode))
            shiftedindex = _invertindex(rlog, rev)
        except (IOError, error.RevlogError):
            # no shift
            shiftedindex = 0
            oldbranch = ""
    else:
        shiftedindex = 0
        oldbranch = ""

    if not branch:
        if not oldbranch:
            reverseindex = shiftedindex + reverseindex
        # else: previous command was branch undo
        # perform absolute undo (no shift)
    else:
        # check if relative branch
        if (branch != oldbranch) and (oldbranch != ""):
            rootdelta = revsetlang.formatspec(
                'roots(_localbranch(%s)) - roots(_localbranch(%s))',
                branch, oldbranch)
            if repo.revs(rootdelta):
                # different group of commits
                shiftedindex = 0

        # from shifted index, find reverse index # of states that change
        # branch
        # remember that reverseindex can be negative
        sign = reverseindex / abs(reverseindex)
        for count in range(abs(reverseindex)):
            shiftedindex = _findnextdelta(repo, shiftedindex, branch,
                                          direction=sign)
        reverseindex = shiftedindex
    return reverseindex

def _findnextdelta(repo, reverseindex, branch, direction):
    # finds closest repos state making changes to branch in direction
    # input:
    #   repo: mercurial.localrepo
    #   reverseindex: positive int for index.i
    #   branch: string changectx (commit hash)
    #   direction: positive or negative int
    # output:
    #   int index with next branch delta
    #   this is the first repo state that makes a changectx, bookmark or working
    #   copy parent change that effects the given branch
    if 0 == direction: # no infinite cycles guarantee
        raise error.ProgrammingError
    repo = repo.unfiltered()
    # current state
    try:
        nodedict = _readindex(repo, reverseindex)
    except IndexError:
        raise error.Abort(_("index out of bounds"))
    alphaworkingcopyparent = _readnode(repo, "workingparent.i",
                                       nodedict["workingparent"])
    alphabookstring = _readnode(repo, "bookmarks.i",
                                nodedict["bookmarks"])
    incrementalindex = reverseindex

    spec = revsetlang.formatspec("_localbranch(%s)", branch)
    hexnodes = tohexnode(repo, spec)

    done = False
    while not done:
        # move index
        incrementalindex += direction
        # check this index
        try:
            nodedict = _readindex(repo, incrementalindex)
        except IndexError:
            raise error.Abort(_("index out of bounds"))
        # check wkp, commits, bookmarks
        workingcopyparent = _readnode(repo, "workingparent.i",
                                      nodedict["workingparent"])
        bookstring = _readnode(repo, "bookmarks.i", nodedict["bookmarks"])
        # local changes in respect to visible changectxs
        # disjunctive union of present and old = changes
        # intersection of changes and local = localchanges
        localctxchanges = revsetlang.formatspec(
            '((olddraft(%d) + olddraft(%d)) -'
            '(olddraft(%d) and olddraft(%d)))'
            ' and _localbranch(%s)',
            incrementalindex, reverseindex,
            incrementalindex, reverseindex,
            branch)
        done = done or repo.revs(localctxchanges)
        if done: # perf boost
            break
        # bookmark changes
        if alphabookstring != bookstring:
            diff = set(alphabookstring.split("\n")) ^\
                   set(bookstring.split("\n"))
            for mark in diff:
                if mark:
                    kv = mark.rsplit(" ", 1)
                    # was or will the mark be in the localbranch
                    if kv[1] in hexnodes:
                        done = True
                        break

        # working copy parent changes
        # for workingcopyparent, only changes within the scope are interesting
        if alphaworkingcopyparent != workingcopyparent:
            done = done or (workingcopyparent in hexnodes and
                            alphaworkingcopyparent in hexnodes)

    return incrementalindex

# hide and reveal commits
def smarthide(repo, revhide, revshow, local=False):
    '''hides changecontexts and reveals some commits

    tries to connect related hides and shows with obs marker
    when reasonable and correct

    use local to not hide revhides without corresponding revshows
    '''
    hidectxs = repo.set(revhide)
    showctxs = repo.set(revshow)
    for ctx in hidectxs:
        unfi = repo.unfiltered()
        related = []
        related = set(obsutil.allprecursors(unfi.obsstore, [ctx.node()]))
        related.update(obsutil.allsuccessors(unfi.obsstore, [ctx.node()]))
        related.intersection_update(x.node() for x in showctxs)
        destinations = [repo[x] for x in related]
        # two primary objectives:
        # 1. correct divergence/nondivergence
        # 2. correct visibility of changesets for the user
        # secondary objectives:
        # 3. usefull ui message in hg sl: "Undone to"
        # Design choices:
        # 1-to-1 correspondence is easy
        # 1-to-many correspondence is hard:
        #   it's either divergent A to B, A to C
        #   or split A to B,C
        #   because of undo we don't know which
        #   without complex logic
        # Solution: provide helpfull ui message for
        # common and easy case (1 to 1), use simplest
        # correct solution for complex edge case
        if len(destinations) == 1:
            hidecommits(repo, ctx, destinations)
        elif len(destinations) > 1: # split
            hidecommits(repo, ctx, [])
        elif len(destinations) == 0:
            if not local:
                hidecommits(repo, ctx, [])

def hidecommits(repo, curctx, precctxs):
    obsolete.createmarkers(repo, [(curctx, precctxs)], operation='undo')

def revealcommits(repo, rev):
    try:
        inhibit = extensions.find('inhibit')
    except KeyError:
        raise error.Abort(_('undo requires inhibit to work properly'))
    else:
        ctxts = repo.set(rev)
        inhibit.revive(ctxts)

def _preview(ui, repo, reverseindex):
    # Print smartlog like preview of undo
    # Input:
    #   ui:
    #   repo: mercurial.localrepo
    # Output:
    #   None

    # override "UNDOINDEX" as a variable usable in template
    overrides = {
        ('templates', 'UNDOINDEX'): str(reverseindex),
    }

    opts = {}
    opts["template"] = "{undopreview}"
    repo = repo.unfiltered()
    revstring = revsetlang.formatspec("olddraft(%d) + olddraft(0)",
                                      reverseindex)
    opts['rev'] = [revstring]
    try:
        with ui.configoverride(overrides):
            cmdutil.graphlog(ui, repo, None, opts)
    except IndexError:
        # don't print anything
        pass

# Tools

def _invertindex(rlog, indexorreverseindex):
    return len(rlog) - 1 - indexorreverseindex

def _getrevlog(repo, filename):
    path = 'undolog/' + filename
    try:
        return revlog.revlog(repo.vfs, path)
    except error.RevlogError:
        # corruption: for now, we can simply nuke all files
        # TODO: log to Scuba
        repo.ui.debug("caught revlog error. %s was probably corrupted\n" % path)
        repo.vfs.rmtree('undolog')
        repo.vfs.makedirs('undolog')
        # if we get the error a second time
        # then someone is actively messing with these files
        return revlog.revlog(repo.vfs, path)

def tohexnode(repo, spec):
    revs = repo.revs(spec)
    tonode = repo.changelog.node
    hexnodes = [hex(tonode(x)) for x in revs]
    return hexnodes
