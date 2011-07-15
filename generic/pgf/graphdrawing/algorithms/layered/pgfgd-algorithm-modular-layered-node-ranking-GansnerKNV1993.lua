-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/layered/pgfgd-algorithm-GansnerKNV1993-layered.lua,v 1.1 2011/07/14 18:18:53 jannis-pohlmann Exp $

pgf.module("pgf.graphdrawing")



NodeRankingGansnerKNV1993 = {}
NodeRankingGansnerKNV1993.__index = NodeRankingGansnerKNV1993



function NodeRankingGansnerKNV1993:new(graph)
  local algorithm = {
    graph = graph,
  }
  setmetatable(algorithm, NodeRankingGansnerKNV1993)
  return algorithm
end



function NodeRankingGansnerKNV1993:run()
  local simplex = NetworkSimplex:new(self.graph, NetworkSimplex.BALANCE_TOP_BOTTOM)
  simplex:run()
  return simplex.ranking
end
