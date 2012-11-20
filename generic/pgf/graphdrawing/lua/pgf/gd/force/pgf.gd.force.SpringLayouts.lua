-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/trees/pgf.gd.trees.lua,v 1.1 2012/04/19 15:22:29 tantau Exp $


-- Imports
local declare = require("pgf.gd.interface.InterfaceToAlgorithms").declare


---
-- @section subsection {Spring Layouts}
--

local _



---

declare {
  key = "spring layout",
  { key = "spring Hu 2006 layout" },

  documentation = [["  
       This key selects Hu's 2006 spring layout with appropriate settings
       for some parameters.
   "]]
 }
