# connectionpool.py - class for pooling peer connections for reuse
#
# Copyright 2017 Facebook, Inc.
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from mercurial import (
    extensions,
    hg,
    sshpeer,
    util,
)

class connectionpool(object):
    def __init__(self, repo):
        self._repo = repo
        self._pool = dict()

    def get(self, path):
        pathpool = self._pool.get(path)
        if pathpool is None:
            pathpool = list()
            self._pool[path] = pathpool

        conn = None
        if len(pathpool) > 0:
            try:
                conn = pathpool.pop()
                peer = conn.peer
                # If the connection has died, drop it
                if (isinstance(peer, sshpeer.sshpeer) and
                    peer.subprocess.poll() is not None):
                    conn = None
            except IndexError:
                pass

        if conn is None:
            def _cleanup(orig):
                # close pipee first so peer.cleanup reading it won't deadlock,
                # if there are other processes with pipeo open (i.e. us).
                peer = orig.im_self
                if util.safehasattr(peer, 'pipee'):
                    peer.pipee.close()
                return orig()

            peer = hg.peer(self._repo.ui, {}, path)
            if util.safehasattr(peer, 'cleanup'):
                extensions.wrapfunction(peer, 'cleanup', _cleanup)

            conn = connection(pathpool, peer)

        return conn

    def close(self):
        for pathpool in self._pool.itervalues():
            for conn in pathpool:
                conn.close()
            del pathpool[:]

class connection(object):
    def __init__(self, pool, peer):
        self._pool = pool
        self.peer = peer

    def __enter__(self):
        return self

    def __exit__(self, type, value, traceback):
        # Only add the connection back to the pool if there was no exception,
        # since an exception could mean the connection is not in a reusable
        # state.
        if type is None:
            self._pool.append(self)
        else:
            self.close()

    def close(self):
        if util.safehasattr(self.peer, 'cleanup'):
            self.peer.cleanup()
