-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/core/lualayer/pgflibrarygraphdrawing-traversal.lua,v 1.1 2011/05/06 15:12:16 jannis-pohlmann Exp $

--- This file contains a number of standard graph algorithms such as Dijkstra.

pgf.module("pgf.graphdrawing")



algorithms = {}



--- Performs the Dijkstra algorithm to solve the single-source shortes path problem.
--
-- The algorithm computes the shortest paths from \meta{source} to all nodes 
-- in the graph. It also generates a table with distance level sets, each of 
-- which  contain all nodes that have the same corresponding distance to 
-- \meta{source}. Finally, a mapping of nodes to their parents along the
-- shortest paths is generated to allow the reconstruction of the paths
-- that were chosen by the Dijkstra algorithm.
--
-- @param graph  The graph to compute the shortest paths for.
-- @param source The node to compute the distances to.
--
-- @return A mapping of nodes to their distance to \meta{source}. 
-- @return An array of distance level sets. The set at index |i| contains
--         all nodes that have a distance of |i| to \meta{source}.
-- @return A mapping of nodes to their parents to allow the reconstruction
--         of the shortest paths chosen by the Dijkstra algorithm.
--
function algorithms.dijkstra(graph, source)
  local distance = {}
  local levels = {}
  local parent = {}

  local queue = PriorityQueue:new()

  -- reset the distance of all nodes and insert them into the priority queue
  for node in table.value_iter(graph.nodes) do
    if node == source then
      distance[node] = 0
      parent[node] = nil
      queue:enqueue(node, distance[node])
    else
      distance[node] = #graph.nodes + 1 -- this is about infinity ;)
      queue:enqueue(node, distance[node])
    end
  end

  while not queue:isEmpty() do
    local u = queue:dequeue()

    assert(distance[u] < #graph.nodes + 1, 'the graph is not connected, Dijkstra will not work')

    if distance[u] > 0 then
      levels[distance[u]] = levels[distance[u]] or {}
      table.insert(levels[distance[u]], u)
    end

    for edge in table.value_iter(u.edges) do
      local v = edge:getNeighbour(u)
      local alternative = distance[u] + 1
      if alternative < distance[v] then
        distance[v] = alternative

        parent[v] = u

        -- update the priority of v
        queue:updatePriority(v, distance[v])
      end
    end
  end

  return distance, levels, parent
end
