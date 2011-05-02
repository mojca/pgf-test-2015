-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header:$

pgf.module("pgf.graphdrawing")



function drawGraphAlgorithm_experimental(graph)
  require('pgflibrarygraphdrawing-algorithms-spring.lua')
  drawGraphAlgorithm_spring(graph)

  orientation.adjust(graph)
end
