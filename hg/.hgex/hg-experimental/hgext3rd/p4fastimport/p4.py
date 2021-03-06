# (c) 2017-present Facebook Inc.
from __future__ import absolute_import

import collections
import contextlib
import json
import marshal
import re
import time

from .util import runworker
from mercurial import (
    util,
)

def decodefilename(f):
    """Perforce saves and returns files that have special characters encoded:

        char | encoding
        ---------------
         @   | %40
         #   | %23
         *   | %2A
         %   | %25
    See:
    https://www.perforce.com/perforce/doc.current/manuals/cmdref/filespecs.html
    """
    f = f.replace('%40', '@')
    f = f.replace('%23', '#')
    f = f.replace('%2A', '*')
    # this must be last so that we don't create a sequence that is decodable,
    # e.g.: %252A would lead to %2A and must not be decoded again.
    f = f.replace('%25', '%')
    return f

class P4Exception(Exception):
    pass

def loaditer(f):
    "Yield the dictionary objects generated by p4"
    try:
        while True:
            d = marshal.load(f)
            if not d:
                break
            yield d
    except EOFError:
        pass

def revrange(start=None, end=None):
    """Returns a revrange to filter a Perforce path. If start and end are None
    we return an empty string as lookups without a revrange filter are much
    faster in Perforce"""
    revrange = ""
    if end is not None or start is not None:
        start = '0' if start is None else str(start)
        end = '#head' if end is None else str(end)
        revrange = "@%s,%s" % (start, end)
    return revrange

def parse_info():
    cmd = 'p4 -ztag -G info'
    stdout = util.popen(cmd, mode='rb')
    return marshal.load(stdout)

_config = None
def config(key):
    global _config
    if _config is None:
        _config = parse_info()
    return _config[key]

@contextlib.contextmanager
def retries(num=3, sleeps=0.3):
    for _try in range(1, num + 1):
        try:
            yield
            return
        except Exception:
            if _try == num:
                raise
            time.sleep(sleeps)

def parse_changes(client, startcl=None, endcl=None):
    "Read changes affecting the path"
    cmd = 'p4 --client %s -ztag -G changes -s submitted //%s/...%s' % (
        util.shellquote(client),
        util.shellquote(client),
        revrange(startcl, endcl))

    stdout = util.popen(cmd, mode='rb')
    cur_time = time.time()
    for d in loaditer(stdout):
        c = d.get("change", None)
        oc = d.get("oldChange", None)
        user = d.get("user", None)
        commit_time = d.get("time", None)
        time_diff = (cur_time - int(commit_time)) if commit_time else 0
        if oc:
            yield P4Changelist(int(oc), int(c), user, time_diff)
        elif c:
            yield P4Changelist(int(c), int(c), user, time_diff)

def parse_filelist(client, startcl=None, endcl=None):
    if startcl is None:
        startcl = 0

    cmd = 'p4 --client %s -G files -a //%s/...%s' % (
            util.shellquote(client),
            util.shellquote(client),
            revrange(startcl, endcl))
    stdout = util.popen(cmd, mode='rb')
    for d in loaditer(stdout):
        c = d.get('depotFile', None)
        if c:
            yield d

def parse_where(client, depotname):
    # TODO: investigate if we replace this with exactly one call to
    # where //clientame/...
    cmd = 'p4 --client %s -G where %s' % (
            util.shellquote(client),
            util.shellquote(depotname))
    try:
        with retries(num=3, sleeps=0.3):
            stdout = util.popen(cmd, mode='rb')
            return marshal.load(stdout)
    except Exception:
        raise P4Exception(stdout)

def get_file(path, rev=None, clnum=None):
    """Returns a file from Perforce"""
    r = '#head'
    if rev:
        r = '#%d' % rev
    if clnum:
        r = '@%d' % clnum

    cmd = 'p4 print -q %s%s' % (util.shellquote(path), r)
    with retries(num=5, sleeps=0.3):
        stdout = util.popen(cmd, mode='rb')
        content = stdout.read()
        return content

def parse_cl(clnum):
    """Returns a description of a change given by the clnum. CLnum can be an
    original CL before renaming"""
    cmd = 'p4 -ztag -G describe -O %d' % clnum
    try:
        with retries(num=3, sleeps=0.3):
            stdout = util.popen(cmd, mode='rb')
            return marshal.load(stdout)
    except Exception:
        raise P4Exception(stdout)

def parse_usermap():
    cmd = 'p4 -G users'
    stdout = util.popen(cmd, mode='rb')
    try:
        for d in loaditer(stdout):
            if d.get('User'):
                yield d
    except Exception:
        raise P4Exception(stdout)

def parse_client(client):
    cmd = 'p4 -G client -o %s' % util.shellquote(client)
    try:
        with retries(num=3, sleeps=0.3):
            stdout = util.popen(cmd, mode='rb')
            clientspec = marshal.load(stdout)
    except Exception:
        raise P4Exception(stdout)

    views = {}
    for client in clientspec:
        if client.startswith("View"):
            sview, cview = clientspec[client].split()
            # XXX: use a regex for this
            cview = cview.lstrip('/')  # remove leading // from the local path
            cview = cview[cview.find("/") + 1:] # remove the clientname part
            views[sview] = cview
    return views

def exists_client(client):
    cmd = 'p4 -G clients -e %s' % util.shellquote(client)
    try:
        with retries(num=3, sleeps=0.3):
            stdout = util.popen(cmd, mode='rb')
            for each in loaditer(stdout):
                client_name = each.get('client', None)
                if client_name is not None and client_name == client:
                    return True
            return False
    except Exception:
        raise P4Exception(stdout)

def parse_fstat(clnum, client, filter=None):
    cmd = 'p4 --client %s -G fstat -e %d -T ' \
          '"depotFile,headAction,headType,headRev" "//%s/..."' % (
            util.shellquote(client),
            clnum,
            util.shellquote(client))
    stdout = util.popen(cmd, mode='rb')
    try:
        result = []
        for d in loaditer(stdout):
            if d.get('depotFile') and (filter is None or filter(d)):
                if d['headAction'] in ACTION_ARCHIVE:
                    continue
                result.append({
                    'depotFile': d['depotFile'],
                    'action': d['headAction'],
                    'type': d['headType'],
                })
        return result
    except Exception:
        raise P4Exception(stdout)

def parse_filelog(filelist, client, changelists):
    for cl in changelists:
        fstats = parse_fstat(cl.cl, client,
                             lambda f: f['depotFile'] in filelist)
        for fstat in fstats:
            yield cl.cl, json.dumps(fstat)

def parse_filelogs(ui, client, changelists, filelist):
    # we can probably optimize this by using fstat only in the case-inensitive
    # case and only for conflicts.
    filelogs = collections.defaultdict(dict)
    worker = runworker(ui, parse_filelog, (filelist, client), changelists)
    for cl, jfstat in worker:
            fstat = json.loads(jfstat)
            depotfile = fstat['depotFile'].encode('ascii')
            filelogs[depotfile][cl] = {
                'action': fstat['action'].encode('ascii'),
                'type': fstat['type'].encode('ascii'),
            }
    for p4filename, filelog in filelogs.iteritems():
        yield P4Filelog(p4filename, filelog)

class P4Filelog(object):
    def __init__(self, depotfile, data):
        self._data = data
        self._depotfile = depotfile

#    @property
#    def branchcl(self):
#        return self._parsed[1]
#
#    @property
#    def branchsource(self):
#        if self.branchcl:
#            return self.parsed[self.branchcl]['from']
#        return None
#
#    @property
#    def branchrev(self):
#        if self.branchcl:
#            return self.parsed[self.branchcl]['rev']
#        return None

    def __cmp__(self, other):
        return (self.depotfile > other.depotfile) - (self.depotfile <
                other.depotfile)

    @property
    def depotfile(self):
        return self._depotfile

    @property
    def revisions(self):
        return sorted(self._data.keys())

    def isdeleted(self, clnum):
        return self._data[clnum]['action'] in ['move/delete', 'delete']

    def isexec(self, clnum):
        t = self._data[clnum]['type']
        return 'xtext' == t or '+x' in t

    def issymlink(self, clnum):
        t = self._data[clnum]['type']
        return 'symlink' in t

    def iskeyworded(self, clnum):
        t = self._data[clnum]['type']
        return (re.compile('kx?text').match(t) or
            re.compile('\+kx?').search(t)) is not None

ACTION_EDIT = ['edit', 'integrate']
ACTION_ADD = ['add', 'branch', 'move/add']
ACTION_DELETE = ['delete', 'move/delete']
ACTION_ARCHIVE = ['archive']
SUPPORTED_ACTIONS = ACTION_EDIT + ACTION_ADD + ACTION_DELETE

class P4Changelist(object):
    def __init__(self, origclnum, clnum, user, commit_time_diff):
        self._clnum = clnum
        self._origclnum = origclnum
        self._user = user
        self._commit_time_diff = commit_time_diff

    def __repr__(self):
        return '<P4Changelist %d>' % self._clnum

    @property
    def cl(self):
        return self._clnum

    @property
    def origcl(self):
        return self._origclnum

    def __cmp__(self, other):
        return (self.cl > other.cl) - (self.cl < other.cl)

    def __hash__(self):
        """Ensure we are matching changelist numbers in sets and hashtables,
        which the importer uses to ensure uniqueness of an imported changeset"""
        return hash((self.origcl, self.cl))

    @util.propertycache
    def parsed(self):
        return self.load()

    def load(self):
        """Parse perforces awkward format"""
        files = {}
        info = parse_cl(self._clnum)
        i = 0
        while True:
            fidx = 'depotFile%d' % i
            aidx = 'action%d' % i
            ridx = 'rev%d' % i
#XXX: Handle oldChange vs change
            if fidx not in info:
                break
            filename = info[fidx]
            files[filename] = {
                'rev': int(info[ridx]),
                'action': info[aidx],
            }
            i += 1
        return {
            'files': files,
            'desc': info['desc'],
            'user': info['user'],
            'time': int(info['time']),
        }

    def rev(self, fname):
        return self.parsed['files'][fname]['rev']

    @property
    def files(self):
        """Returns added, modified and removed files for a changelist.

        The current mapping is:

        Mercurial  | Perforce
        ---------------------
        add        | add, branch, move/add
        modified   | edit, integrate
        removed    | delete, move/delte, archive
        """
        a, m, r = [], [], []
        for fname, info in self.parsed['files'].iteritems():
            if info['action'] in ACTION_EDIT:
                m.append(fname)
            elif info['action'] in ACTION_ADD:
                a.append(fname)
            elif info['action'] in ACTION_DELETE + ACTION_ARCHIVE:
                r.append(fname)
            else:
                assert False
        return a, m, r
