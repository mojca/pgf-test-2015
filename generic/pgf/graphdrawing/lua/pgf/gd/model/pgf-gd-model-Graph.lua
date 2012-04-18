-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/model/pgf-gd-model-Graph.lua,v 1.1 2012/04/16 22:40:29 tantau Exp $




--- The Graph class ...
--
--

local Graph = pgf.graphdrawing.Graph
Graph.__index = Graph


-- Namespace

local model   = require "pgf.gd.model"
model.Graph = Graph



-- Done

return Graph