-- Copyright 2010 by Renée Ahrens, Olof Frahm, Jens Kluttig, Matthias Schulz, Stephan Schuster
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/libraries/graphdrawing/lua/pgflibrarygraphdrawing-files.lua,v 1.7 2011/05/02 02:33:08 jannis-pohlmann Exp $

-- This file defines a list of initial files to load.

local files = {
   "module",
   "helper",
   "sys",
   "position",
   "path",
   "box",
   "node",
   "edge",
   "graph",
   "algorithms-localsearchgraph",
   "component-packing",
   "interface",
   "iter-helpers",
   "orientation",
   "positioning-helpers",
   "vector",
   "traversal-helpers",
   "table-helpers",
   "texboxregister",
   "test-position",
   "test-path",
   "test-box",
   "test-vector",
}

return files
