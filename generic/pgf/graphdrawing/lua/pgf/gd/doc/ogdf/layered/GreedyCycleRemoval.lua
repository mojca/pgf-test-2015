-- Copyright 2013 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/ogdf/layered/SugiyamaLayout.documentation.lua,v 1.2 2013/03/04 14:15:30 tantau Exp $


local key           = require 'pgf.gd.doc'.key
local documentation = require 'pgf.gd.doc'.documentation
local summary       = require 'pgf.gd.doc'.summary
local example       = require 'pgf.gd.doc'.example


--------------------------------------------------------------------
key          "GreedyCycleRemoval"
summary      "Greedy algorithm for computing a maximal acyclic subgraph."
documentation
[[
The algorithm applies a greedy heuristic to compute a maximal
acyclic subgraph and works in linear-time. 
]]
--------------------------------------------------------------------
