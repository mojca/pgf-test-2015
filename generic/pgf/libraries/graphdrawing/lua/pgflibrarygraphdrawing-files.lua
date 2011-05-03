-- Copyright 2010 by Renée Ahrens, Olof Frahm, Jens Kluttig, Matthias Schulz, Stephan Schuster
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/libraries/graphdrawing/lua/pgflibrarygraphdrawing-files.lua,v 1.9 2011/05/03 11:24:43 jannis-pohlmann Exp $

-- This file defines a list of initial files to load.

local files = {
   "module",
   "table",
   "iter",
   "string",
   "sys",
   "vector",
   "quadtree",
   "path",
   "box",
   "node",
   "edge",
   "graph",
   "traversal",
   "component-packing",
   "interface",
   "orientation",
   "positioning-helpers",
   "texboxregister",
   "test-path",
   "test-box",
   "test-vector",
   "test-quadtree",
}

return files
