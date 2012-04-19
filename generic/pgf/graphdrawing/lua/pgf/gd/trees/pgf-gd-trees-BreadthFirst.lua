-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/trees/pgfgd-subalgorithm-SpanningTreeBreadthFirst.lua,v 1.2 2012/04/16 22:40:29 tantau Exp $



--- A (sub)algorithm for computing spanning trees
--
-- This algorithm will compute a spanning tree of a graph using the
-- breadth first method.

local BreadthFirst = pgf.gd.new_algorithm_class {}

-- Namespace
require("pgf.gd.trees").BreadthFirst = BreadthFirst

-- Imports
local Simplifiers = require "pgf.gd.lib.Simplifiers"


--- Compute a spanning tree of a graph
--
-- The computed spanning tree will be available through the fields
-- algorithm.children of each node and algorithm.spanning_tree_root of
-- the graph.
--
-- @param graph The graph for which the spanning tree should be computed 

function BreadthFirst:run ()
  Simplifiers:computeSpanningTree(self.parent_algorithm, false)
end


return BreadthFirst