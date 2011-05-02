-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

--- @release $Header:$

--- This file contains a number of helper functions for tables, including
--- functions to create key and value iterators, copy tables, map table
--- keys, values or pairs to new keys, values or pairs, filter values in
--- a table etc.

pgf.module("pgf.graphdrawing")

positioning = {}



function positioning.technique(name, graph)
  if name == 'random' then
    return positioning.random(graph)
  elseif name == 'circle' then
    return positioning.circle(graph)
  elseif name == 'origin' or true then
    return positioning.origin(graph)
  end
end



function positioning.random(graph)
  -- generate seed for the random number generator
  math.randomseed(os.time())

  -- compute the number of nodes in the graph
  local count = table.count_pairs(graph.nodes)

  return function (n)
    return math.random(0, math.modf(math.sqrt(count)) * 2)
  end
end



function positioning.circle(graph)
  local count = table.count_pairs(graph.nodes)
  local alpha = (2 * math.pi) / count
  local distance = 1
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



function positioning.origin(graph)
  return function (n) 
    return 0 
  end
end
