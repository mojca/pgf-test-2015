-- Copyright 2011 by Jannis Pohlmann, 2012 by Till Tantau
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/layered/pgfgd-algorithm-ModularLayeredSugiyama.lua,v 1.5 2012/04/16 17:58:35 tantau Exp $


local control = require "pgf.gd.control"
local lib     = require "pgf.gd.lib"


--- An implementation of a modular version of the Sugiyama method

graph_drawing_algorithm {
  name = 'ModularLayeredSugiyama',
  properties = {
    works_only_on_connected_graphs = true,
    works_only_for_loop_free_graphs = true,
    growth_direction = 90,
  },
  graph_parameters = {
    level_distance = {'level distance', tonumber},
    sibling_distance = {'sibling distance', tonumber},
    random_seed = {'layered layout/random seed', tonumber},
    cycle_removal_algorithm = 'layered layout/cycle removal',
    node_ranking_algorithm = 'layered layout/node ranking',
    crossing_minimization_algorithm = 'layered layout/crossing minimization',
    node_positioning_algorithm = 'layered layout/node positioning',
    edge_routing_algorithm = 'layered layout/edge routing',
  }
}



function ModularLayeredSugiyama:run()
  if #self.graph.nodes <= 1 then
     return
  end

  -- apply the random seed specified by the user (only if it is non-zero)
  if self.random_seed ~= 0 then
    math.randomseed(self.random_seed)
  end
  
  self:preprocess()


  -- Helper function for collapsing multiedges
  local function collapse (m,e)
    m.weight         = (m.weight or 0) + e.weight
    m.minimum_levels = math.max((m.minimum_levels or 0), e.minimum_levels)
  end

  -- Rank using cluster

  -- Create a subalgorithm object. Needed so that removed loops
  -- are not stored on top of removed loops from main call.
  local cluster_subalgorithm = { graph = self.graph } 
  self.graph:registerAlgorithm(cluster_subalgorithm)

  self:mergeClusters()
  
  lib.Simplifiers:removeLoops(cluster_subalgorithm)
  lib.Simplifiers:collapseMultiedges(cluster_subalgorithm, collapse)

  self:removeCycles()
  self:rankNodes()
  self:restoreCycles()

  lib.Simplifiers:expandMultiedges(cluster_subalgorithm)
  lib.Simplifiers:restoreLoops(cluster_subalgorithm)

  self:expandClusters()
  
  -- Now do actual computation
  lib.Simplifiers:collapseMultiedges(cluster_subalgorithm, collapse)
  self:removeCycles()
  self:insertDummyNodes()
  
  -- Main algorithm
  self:reduceEdgeCrossings()
  self:positionNodes()
  
  -- Cleanup
  self:removeDummyNodes()
  lib.Simplifiers:expandMultiedges(cluster_subalgorithm)
  self:routeEdges()
  self:restoreCycles()

  self:postprocess()
end



function ModularLayeredSugiyama:preprocess()
  -- initialize edge parameters
  for edge in table.value_iter(self.graph.edges) do
    -- read edge parameters
    edge.weight = tonumber(edge:getOption('/graph drawing/layered layout/weight'))
    edge.minimum_levels = tonumber(edge:getOption('/graph drawing/layered layout/minimum levels'))

    -- validate edge parameters
    assert(edge.minimum_levels >= 0, 'the edge ' .. tostring(edge) .. ' needs to have a minimum levels value greater than or equal to 0')
  end
end



function ModularLayeredSugiyama:insertDummyNodes()
  -- enumerate dummy nodes using a globally unique numeric ID
  local dummy_id = 1

  -- keep track of the original edges removed
  self.original_edges = {}

  -- keep track of dummy nodes introduced
  self.dummy_nodes = {}

  for node in traversal.topological_sorting(self.graph) do
    local in_edges = node:getIncomingEdges()

    for edge in table.value_iter (in_edges) do
      local neighbour = edge:getNeighbour(node)
      local dist = self.ranking:getRank(node) - self.ranking:getRank(neighbour)

      if dist > 1 then
        local dummies = {}

        for i in iter.times(dist-1) do
          local rank = self.ranking:getRank(neighbour) + i

          local dummy = VirtualNode:new{
            pos = lib.Vector:new(),
            name = 'dummy@' .. neighbour.name .. '@to@' .. node.name .. '@at@' .. rank,
          }

          dummy_id = dummy_id + 1

          self.graph:addNode(dummy)

          self.ranking:setRank(dummy, rank)

          table.insert(self.dummy_nodes, dummy)
          table.insert(edge.bend_nodes, dummy)

          table.insert(dummies, dummy)
        end

        table.insert(dummies, 1, neighbour)
        table.insert(dummies, #dummies+1, node)

        for i = 2, #dummies do
          local source = dummies[i-1]
          local target = dummies[i]

          local dummy_edge = Edge:new{
            direction = Edge.RIGHT, 
            reversed = false,
            weight = edge.weight, -- TODO or should we divide the weight of the original edge by the number of virtual edges?
          }

          dummy_edge:addNode(source)
          dummy_edge:addNode(target)

          self.graph:addEdge(dummy_edge)
        end

        table.insert(self.original_edges, edge)
      end
    end
  end

  for edge in table.value_iter(self.original_edges) do
    self.graph:deleteEdge(edge)
  end
end



function ModularLayeredSugiyama:removeDummyNodes()
  -- delete dummy nodes
  for node in table.value_iter(self.dummy_nodes) do
    self.graph:deleteNode(node)
  end

  -- add original edge again
  for edge in table.value_iter(self.original_edges) do
    -- add edge to the graph
    self.graph:addEdge(edge)

    -- add edge to the nodes
    for node in table.value_iter(edge.nodes) do
      node:addEdge(edge)
    end

    -- convert bend nodes to bend points for TikZ
    for bend_node in table.value_iter(edge.bend_nodes) do
      local point = bend_node.pos:copy()
      table.insert(edge.bend_points, point)
    end

    if edge.reversed then
      edge.bend_points = table.reverse_values(edge.bend_points, edge.bend_points)
    end

    -- clear the list of bend nodes
    edge.bend_nodes = {}
  end
end



function ModularLayeredSugiyama:mergeClusters()

  self.cluster_nodes = {}
  self.cluster_node = {}
  self.cluster_edges = {}
  self.cluster_original_edges = {}
  self.original_nodes = {}

  for cluster in table.value_iter(self.graph.clusters) do

    local cluster_node = cluster.nodes[1]
    table.insert(self.cluster_nodes, cluster_node)

    for n = 2, #cluster.nodes do
      local other_node = cluster.nodes[n]
      self.cluster_node[other_node] = cluster_node
      table.insert(self.original_nodes, other_node)
    end
  end

  for edge in table.value_iter(self.graph.edges) do
    local tail = edge:getTail()
    local head = edge:getHead()

    if self.cluster_node[tail] or self.cluster_node[head] then
      local cluster_edge = Edge:new{
        direction = Edge.RIGHT,
        weight = edge.weight,
        minimum_levels = edge.minimum_levels,
      }

      if self.cluster_node[tail] then
        cluster_edge:addNode(self.cluster_node[tail])
      else
        cluster_edge:addNode(tail)
      end

      if self.cluster_node[head] then
        cluster_edge:addNode(self.cluster_node[head])
      else
        cluster_edge:addNode(head)
      end

      table.insert(self.cluster_edges, cluster_edge)
      table.insert(self.cluster_original_edges, edge)
    end
  end

  for n = 1, #self.cluster_nodes-1 do
    local first_node = self.cluster_nodes[n]
    local second_node = self.cluster_nodes[n+1]

    local edge = Edge:new{
      direction = Edge.RIGHT,
      weight = 1,
      minimum_levels = 1,
    }

    edge:addNode(first_node)
    edge:addNode(second_node)

    table.insert(self.cluster_edges, edge)
  end

  for node in table.value_iter(self.original_nodes) do
    self.graph:deleteNode(node)
  end
  for edge in table.value_iter(self.cluster_edges) do
    self.graph:addEdge(edge)
  end
  for edge in table.value_iter(self.cluster_original_edges) do
    self.graph:deleteEdge(edge)
  end
end



function ModularLayeredSugiyama:expandClusters()

  for node in table.value_iter(self.original_nodes) do
    self.ranking:setRank(node, self.ranking:getRank(self.cluster_node[node]))
    self.graph:addNode(node)
  end

  for edge in table.value_iter(self.cluster_original_edges) do
    for node in table.value_iter(edge.nodes) do
      node:addEdge(edge)
    end
    self.graph:addEdge(edge)
  end

  for edge in table.value_iter(self.cluster_edges) do
    self.graph:deleteEdge(edge)
  end
end




function ModularLayeredSugiyama:removeCycles()
  local name, class = self:loadSubAlgorithm('CycleRemoval', self.cycle_removal_algorithm)
  
  assert(class, 'the cycle removal algorithm "' .. self.cycle_removal_algorithm .. '" could not be found')

  local algorithm = class:new(self, self.graph)
  algorithm:run()
end



function ModularLayeredSugiyama:rankNodes()
  local name, class = self:loadSubAlgorithm('NodeRanking', self.node_ranking_algorithm)
  
  assert(class, 'the node ranking algorithm "' .. self.node_ranking_algorithm .. '" could not be found')

  local algorithm = class:new(self, self.graph)
  self.ranking = algorithm:run()
  
  assert(self.ranking and self.ranking.__index == Ranking, 'the node ranking algorithm "' .. tostring(name) .. '" did not return a ranking')
end



function ModularLayeredSugiyama:reduceEdgeCrossings()
  local name, class = self:loadSubAlgorithm('CrossingMinimization', self.crossing_minimization_algorithm)

  assert(class, 'the crossing minimzation algorithm "' .. self.crossing_minimization_algorithm .. '" could not be found')

  local algorithm = class:new(self, self.graph, self.ranking)
  self.ranking = algorithm:run()
  
  assert(self.ranking and self.ranking.__index == Ranking, 'the crossing minimization algorithm "' .. tostring(name) .. '" did not return a ranking')
end




function ModularLayeredSugiyama:positionNodes()
  local name, class = self:loadSubAlgorithm('NodePositioning', self.node_positioning_algorithm)

  assert(class, 'the node positioning algorithm "' .. self.node_positioning_algorithm .. '" could not be found')

  local algorithm = class:new(self, self.graph, self.ranking)
  algorithm:run()
end



function ModularLayeredSugiyama:routeEdges()
  local name, class = self:loadSubAlgorithm('EdgeRouting', self.edge_routing_algorithm)

  assert(class, 'the edge routing algorithm "' .. self.edge_routing_algorithm .. '" could not be found')

  local algorithm = class:new(self, self.graph)
  algorithm:run()
end



function ModularLayeredSugiyama:restoreCycles()
  for edge in table.value_iter(self.graph.edges) do
    edge.reversed = false
  end
end



function ModularLayeredSugiyama:postprocess()
end



function ModularLayeredSugiyama:loadSubAlgorithm(step, name)
  -- make sure there are no spaces in the file name
  name = name:gsub(' ', '')

  local classname = step .. name
  local filename = 'pgfgd-subalgorithm-' .. classname .. '.lua'

  pgf.load(filename, 'tex', false)

  return classname, pgf.graphdrawing[classname]
end


