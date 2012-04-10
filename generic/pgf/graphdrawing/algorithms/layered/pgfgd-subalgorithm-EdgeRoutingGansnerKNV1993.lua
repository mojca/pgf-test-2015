-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/layered/pgfgd-subalgorithm-EdgeRoutingGansnerKNV1993.lua,v 1.1 2012/04/01 21:54:46 tantau Exp $

pgf.module("pgf.graphdrawing")



EdgeRoutingGansnerKNV1993 = {}
EdgeRoutingGansnerKNV1993.__index = EdgeRoutingGansnerKNV1993



function EdgeRoutingGansnerKNV1993:new(main_algorithm, graph)
  local algorithm = {
    main_algorithm = main_algorithm,
    graph = graph,
  }
  setmetatable(algorithm, EdgeRoutingGansnerKNV1993)
  return algorithm
end



function EdgeRoutingGansnerKNV1993:run()
end
