-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/core/lualayer/pgflibrarygraphdrawing-positioning-helpers.lua,v 1.2 2011/05/13 01:23:49 jannis-pohlmann Exp $

--- This file contains a number of helper functions for tables, including
--- functions to create key and value iterators, copy tables, map table
--- keys, values or pairs to new keys, values or pairs, filter values in
--- a table etc.

pgf.module("pgf.graphdrawing")

positioning = {}



function positioning.technique(name, graph, distance)
  if name == 'random' then
    return positioning.random(graph, distance)
  elseif name == 'circle' then
    return positioning.circle(graph, distance)
  elseif name == 'origin' or true then
    return positioning.origin(graph, distance)
  end
end



function positioning.random(graph, distance)
  return function (n)
    -- TODO revise this and check which of the two lines is batter
    -- return math.random(0, math.modf(math.sqrt(#graph.nodes)) * 2 * distance)
    return math.random(0, 2.5 * distance)
  end
end



function positioning.circle(graph, distance)
  local alpha = (2 * math.pi) / #graph.nodes
  local radius = distance / (2 * math.sin(alpha / 2))
  local i = 0

  return function (n)
    if n == 1 then
      return radius * math.cos(i * alpha)
    else
      i = i + 1
      return radius * math.sin((i - 1) * alpha)
    end
  end
end



function positioning.origin(graph, distance)
  return function (n) 
    return 0 
  end
end
