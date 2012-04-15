-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/core/lualayer/control/pgfgd-core-spanning-tree.lua,v 1.2 2012/04/15 17:21:25 tantau Exp $

-- This file defines an edge class, used in the graph representation.

pgf.module("pgf.graphdrawing")





--- A subalgorithm for computing spanning trees
--
-- This algorithm will compute a spanning tree of a graph using the
-- breadth first method.

graph_drawing_algorithm {
  name = 'SpanningTreeDepthFirst',
}



--- Compute a spanning tree of a graph
--
-- The computed spanning tree will be available through the fields
-- algorithm.children of each node and algorithm.spanning_tree_root of
-- the graph.
--
-- @param graph The graph for which the spanning tree should be computed 

function SpanningTreeDepthFirst:run ()

  local algorithm = self.parent_algorithm
  local graph = self.graph

  compute_spanning_tree(algorithm, true)
end
