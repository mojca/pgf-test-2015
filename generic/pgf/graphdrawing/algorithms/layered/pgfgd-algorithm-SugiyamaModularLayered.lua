-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed and/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/layered/pgfgd-algorithm-SugiyamaModularLayered.lua,v 1.1 2012/04/01 22:06:08 tantau Exp $

pgf.module("pgf.graphdrawing")



--- An implementation of a modular version of the Sugiyama method

SugiyamaModularLayered = {
  growth_direction = -90 -- This algorithm will "grow" things "down"
}
SugiyamaModularLayered.__index = SugiyamaModularLayered

function SugiyamaModularLayered:constructor()
   self.random_seed = tonumber(self.graph:getOption('/graph drawing/layered layout/random seed'))

   -- read graph input parameters
   self.level_distance = tonumber(self.graph:getOption('/graph drawing/level distance'))
   self.sibling_distance = tonumber(self.graph:getOption('/graph drawing/sibling distance'))

   -- read sub-algorithm parameters
   self.cycle_removal_algorithm = tostring(self.graph:getOption('/graph drawing/layered layout/cycle removal'))
   self.node_ranking_algorithm = tostring(self.graph:getOption('/graph drawing/layered layout/node ranking'))
   self.crossing_minimization_algorithm = tostring(self.graph:getOption('/graph drawing/layered layout/crossing minimization'))
   self.node_positioning_algorithm = tostring(self.graph:getOption('/graph drawing/layered layout/node positioning'))
   self.edge_routing_algorithm = tostring(self.graph:getOption('/graph drawing/layered layout/edge routing'))
  
   -- validate input parameters
   assert(self.level_distance >= 0, 'the level distance needs to be greater than or equal to 0')
   assert(self.sibling_distance >= 0, 'the sibling distance needs to be greater than or equal to 0')
end



function SugiyamaModularLayered:run()
  if #self.graph.nodes <= 1 then
     return
  end

  -- apply the random seed specified by the user (only if it is non-zero)
  if self.random_seed ~= 0 then
    math.randomseed(self.random_seed)
  end

  self:dumpGraph('before preprocessing')
  self:preprocess()

  self:mergeClusters()

  self:dumpGraph('before removing loops')
  self:removeLoops()

  self:dumpGraph('before merging multiedges')
  self:mergeMultiEdges()

  self:dumpGraph('before removing cycles')
  self:removeCycles()
  
  self:dumpGraph('before ranking nodes')
  self:rankNodes()

  self:dumpGraph('before restoring cycles')
  self:restoreCycles()

  self:dumpGraph('before restoring multiedges')
  self:restoreMultiEdges()

  self:dumpGraph('before restoring loops')
  self:restoreLoops()

  self:expandClusters()

  self:removeLoops()

  self:mergeMultiEdges()

  self:removeCycles()
  
  self:dumpGraph('before inserting dummy nodes')
  self:insertDummyNodes()
  
  self:dumpGraph('before reducing edge crossings')
  self:reduceEdgeCrossings()

  self:dumpGraph('before positioning nodes')
  self:positionNodes()
  
  self:dumpGraph('before removing dummy nodes')
  self:removeDummyNodes()

  self:dumpGraph('before restoring multiedges')
  self:restoreMultiEdges()

  self:dumpGraph('before restoring loops')
  self:restoreLoops()

  self:dumpGraph('before routing edges')
  self:routeEdges()

  self:dumpGraph('before restoring cycles')
  self:restoreCycles()

  self:dumpGraph('before postprocessing')
  self:postprocess()

  self:dumpGraph('final graph')
  Sys:log('finished')
  Sys:log(' ')
end


function SugiyamaModularLayered:dumpGraph(title)
  Sys:log(title .. ':')
  for node in table.value_iter(self.graph.nodes) do
    Sys:log('  node ' .. node.name)
    for edge in table.value_iter(node.edges) do
      Sys:log('    ' .. tostring(edge))
    end
  end
  for edge in table.value_iter(self.graph.edges) do
    Sys:log('  ' .. tostring(edge))
  end
  for cluster in table.value_iter(self.graph.clusters) do
    local node_strings = table.map_values(cluster.nodes, function (node)
      return node.name
    end)
    Sys:log('  cluster ' .. cluster:getName() .. ': ' .. table.concat(node_strings, ' '))
  end
end




function SugiyamaModularLayered:preprocess()
  -- initialize edge parameters
  for edge in table.value_iter(self.graph.edges) do
    -- read edge parameters
    edge.weight = tonumber(edge:getOption('/graph drawing/layered layout/weight'))
    edge.minimum_levels = tonumber(edge:getOption('/graph drawing/layered layout/minimum levels'))

    -- validate edge parameters
    assert(edge.minimum_levels >= 0, 'the edge ' .. tostring(edge) .. ' needs to have a minimum levels value greater than or equal to 0')
  end
end



function SugiyamaModularLayered:insertDummyNodes()
  Sys:log('insert dummy nodes:')

  self:dumpRanking('  ', 'ranking before inserting dummy nodes')

  -- enumerate dummy nodes using a globally unique numeric ID
  local dummy_id = 1

  -- keep track of the original edges removed
  self.original_edges = {}

  -- keep track of dummy nodes introduced
  self.dummy_nodes = {}

  for node in traversal.topological_sorting(self.graph) do
    Sys:log('  visit ' .. node.name)

    local in_edges = node:getIncomingEdges()

    for edge in table.value_iter (in_edges) do
      local neighbour = edge:getNeighbour(node)
      local dist = self.ranking:getRank(node) - self.ranking:getRank(neighbour)

      Sys:log('    neighbour ' .. neighbour.name .. ', dist = ' .. dist)

      if dist > 1 then
        local dummies = {}

        for i in iter.times(dist-1) do
          local rank = self.ranking:getRank(neighbour) + i

          local dummy = Node:new{
            pos = Vector:new({ 0, 0 }),
            name = 'dummy@' .. neighbour.name .. '@to@' .. node.name .. '@at@' .. rank,
            is_dummy = true,
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

  self:dumpRanking('  ', 'ranking after inserting dummy nodes')
end



function SugiyamaModularLayered:removeDummyNodes()
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
      local point = Vector:new(bend_node.pos.elements)
      table.insert(edge.bend_points, point)
    end

    if edge.reversed then
      edge.bend_points = table.reverse_values(edge.bend_points, edge.bend_points)
    end

    -- clear the list of bend nodes
    edge.bend_nodes = {}
  end
end



function SugiyamaModularLayered:mergeClusters()
  Sys:log('merge clusters:')

  --self.cluster_nodes = {}
  --self.cluster_node = {}
  --self.cluster_edges = {}

  --self.original_nodes = {}
  --self.original_edges = {}

  --for cluster in table.value_iter(self.graph.clusters) do
  --  Sys:log('  merge cluster ' .. cluster:getName())

  --  local cluster_node = Node:new{
  --    name = 'cluster@' .. cluster:getName(),
  --  }
  --  table.insert(self.cluster_nodes, cluster_node)

  --  for node in table.value_iter(cluster.nodes) do
  --    self.cluster_node[node] = cluster_node
  --    table.insert(self.original_nodes, node)
  --  end

  --  self.graph:addNode(cluster_node)
  --end

  --for edge in table.value_iter(self.graph.edges) do
  --  local tail = edge:getTail()
  --  local head = edge:getHead()

  --  if self.cluster_node[tail] or self.cluster_node[head] then
  --    table.insert(self.original_edges, edge)

  --    local cluster_edge = Edge:new{
  --      direction = Edge.RIGHT,
  --      weight = edge.weight,
  --      minimum_levels = edge.minimum_levels,
  --    }
  --    table.insert(self.cluster_edges, cluster_edge)

  --    if self.cluster_node[tail] then
  --      cluster_edge:addNode(self.cluster_node[tail])
  --    else
  --      cluster_edge:addNode(tail)
  --    end

  --    if self.cluster_node[head] then
  --      cluster_edge:addNode(self.cluster_node[head])
  --    else
  --      cluster_edge:addNode(head)
  --    end

  --    Sys:log('  replace edge ' .. tostring(edge) .. ' with ' .. tostring(cluster_edge))
  --  end
  --end

  --for edge in table.value_iter(self.cluster_edges) do
  --  self.graph:addEdge(edge)
  --end

  --for edge in table.value_iter(self.original_edges) do
  --  self.graph:deleteEdge(edge)
  --end

  --for node in table.value_iter(self.original_nodes) do
  --  self.graph:deleteNode(node)
  --end

  self.cluster_nodes = {}
  self.cluster_node = {}
  self.cluster_edges = {}
  self.cluster_original_edges = {}
  self.original_nodes = {}

  for cluster in table.value_iter(self.graph.clusters) do
    Sys:log('  merge cluster ' .. cluster:getName())

    local cluster_node = cluster.nodes[1]
    Sys:log('    representative is ' .. cluster_node.name)
    table.insert(self.cluster_nodes, cluster_node)

    for n = 2, #cluster.nodes do
      local other_node = cluster.nodes[n]
      Sys:log('      merge node ' .. other_node.name .. ' into it')
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

    Sys:log('  add cluster separator edge ' .. tostring(edge))

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

  self:dumpGraph('graph after merging clusters')
end



function SugiyamaModularLayered:expandClusters()
  Sys:log('expand clusters:')

  --for node in table.value_iter(self.original_nodes) do
  --  assert(self.ranking:getRank(self.cluster_node[node]))
  --  self.ranking:setRank(node, self.ranking:getRank(self.cluster_node[node]))
  --  self.graph:addNode(node)
  --end

  --for edge in table.value_iter(self.original_edges) do
  --  for node in table.value_iter(edge.nodes) do
  --    node:addEdge(edge)
  --  end
  --  self.graph:addEdge(edge)
  --end
  --
  --for node in table.value_iter(self.cluster_nodes) do
  --  self.ranking:setRank(node, nil)
  --  self.graph:deleteNode(node)
  --end

  --for edge in table.value_iter(self.cluster_edges) do
  --  self.graph:deleteEdge(edge)
  --end

  for node in table.value_iter(self.original_nodes) do
    Sys:log('  add original node ' .. node.name .. ' back')
    self.ranking:setRank(node, self.ranking:getRank(self.cluster_node[node]))
    self.graph:addNode(node)
  end

  for edge in table.value_iter(self.cluster_original_edges) do
    Sys:log('  add edge ' .. tostring(edge) .. ' back')
    for node in table.value_iter(edge.nodes) do
      node:addEdge(edge)
    end
    self.graph:addEdge(edge)
  end

  for edge in table.value_iter(self.cluster_edges) do
    Sys:log('  delete cluster edge ' .. tostring(edge))
    self.graph:deleteEdge(edge)
  end

  self:dumpGraph('graph after expanding clusters')
end



function SugiyamaModularLayered:removeLoops()
  self.loops = {}

  for edge in table.value_iter(self.graph.edges) do
    if edge:getHead() == edge:getTail() then
      table.insert(self.loops, edge)
    end
  end

  for edge in table.value_iter(self.loops) do
    self.graph:deleteEdge(edge)
  end
end



function SugiyamaModularLayered:mergeMultiEdges()
  self.individual_edges = {}

  Sys:log('merge multiedges:')

  local node_processed = {}

  for node in table.value_iter(self.graph.nodes) do
    Sys:log('  neighbour edges of ' .. node.name)

    node_processed[node] = true

    local multiedge = {}
    
    for edge in table.value_iter(node:getIncomingEdges()) do
      local neighbour = edge:getNeighbour(node)
      if not node_processed[neighbour] then
        if not multiedge[neighbour] then
          multiedge[neighbour] = Edge:new{
            direction = Edge.RIGHT,
            weight = 0,
            minimum_levels = 0,
          }

          self.individual_edges[multiedge[neighbour]] = {}
        end

        multiedge[neighbour].weight = multiedge[neighbour].weight + edge.weight
        multiedge[neighbour].minimum_levels = math.max(multiedge[neighbour].minimum_levels, edge.minimum_levels)

        table.insert(self.individual_edges[multiedge[neighbour]], edge)
      end
    end

    for edge in table.value_iter(node:getOutgoingEdges()) do
      local neighbour = edge:getNeighbour(node)
      if not node_processed[neighbour] then
        if not multiedge[neighbour] then
          multiedge[neighbour] = Edge:new{
            direction = Edge.RIGHT,
            weight = 0,
            minimum_levels = 0,
          }

          self.individual_edges[multiedge[neighbour]] = {}
        end

        multiedge[neighbour].weight = multiedge[neighbour].weight + edge.weight
        multiedge[neighbour].minimum_levels = math.max(multiedge[neighbour].minimum_levels, edge.minimum_levels)

        table.insert(self.individual_edges[multiedge[neighbour]], edge)
      end
    end

    for neighbour, multiedge in pairs(multiedge) do
      Sys:log('    with neighbour ' .. neighbour.name)

      for subedge in table.value_iter(self.individual_edges[multiedge]) do
        Sys:log('      ' .. tostring(subedge))
      end

      if #self.individual_edges[multiedge] <= 1 then
        self.individual_edges[multiedge] = nil
      else
        multiedge.weight = multiedge.weight / #self.individual_edges[multiedge]

        for subedge in table.value_iter(self.individual_edges[multiedge]) do
          self.graph:deleteEdge(subedge)
        end

        multiedge:addNode(node)
        multiedge:addNode(neighbour)
        
        self.graph:addEdge(multiedge)
      end
    end
  end
end



function SugiyamaModularLayered:removeCycles()
  local name, class = self:loadSubAlgorithm('CycleRemoval', self.cycle_removal_algorithm)
  
  assert(class, 'the cycle removal algorithm "' .. self.cycle_removal_algorithm .. '" could not be found')

  Sys:log('remove cycles with ' .. name)

  local algorithm = class:new(self.graph)
  algorithm:run()
end



function SugiyamaModularLayered:rankNodes()
  local name, class = self:loadSubAlgorithm('NodeRanking', self.node_ranking_algorithm)
  
  assert(class, 'the node ranking algorithm "' .. self.node_ranking_algorithm .. '" could not be found')

  Sys:log('rank nodes with ' .. name)

  local algorithm = class:new(self.graph)
  self.ranking = algorithm:run()
  
  assert(self.ranking and self.ranking.__index == Ranking, 'the node ranking algorithm "' .. tostring(name) .. '" did not return a ranking')
end



function SugiyamaModularLayered:reduceEdgeCrossings()
  local name, class = self:loadSubAlgorithm('CrossingMinimization', self.crossing_minimization_algorithm)

  assert(class, 'the crossing minimzation algorithm "' .. self.crossing_minimization_algorithm .. '" could not be found')

  Sys:log('reduce edge crossings with ' .. name)

  local algorithm = class:new(self.graph, self.ranking)
  self.ranking = algorithm:run()
  
  assert(self.ranking and self.ranking.__index == Ranking, 'the crossing minimization algorithm "' .. tostring(name) .. '" did not return a ranking')
end



function SugiyamaModularLayered:restoreMultiEdges()
  for multiedge, subedges in pairs(self.individual_edges) do
    assert(#subedges >= 2)

    Sys:log('restore multiedges of ' .. multiedge:getTail().name .. ' and ' .. multiedge:getHead().name)

    self.graph:deleteEdge(multiedge)

    for edge in table.value_iter(subedges) do
      for node in table.value_iter(edge.nodes) do
        node:addEdge(edge)
      end

      self.graph:addEdge(edge)
    end
  end
end



function SugiyamaModularLayered:positionNodes()
  local name, class = self:loadSubAlgorithm('NodePositioning', self.node_positioning_algorithm)

  assert(class, 'the node positioning algorithm "' .. self.node_positioning_algorithm .. '" could not be found')

  Sys:log('position nodes with ' .. name)

  local algorithm = class:new(self.graph, self.ranking)
  algorithm:run()
end



function SugiyamaModularLayered:restoreLoops()
  for edge in table.value_iter(self.loops) do
    self.graph:addEdge(edge)
    edge:getTail():addEdge(edge)
  end
end



function SugiyamaModularLayered:routeEdges()
  local name, class = self:loadSubAlgorithm('EdgeRouting', self.edge_routing_algorithm)

  assert(class, 'the edge routing algorithm "' .. self.edge_routing_algorithm .. '" could not be found')

  Sys:log('route edges with ' .. name)

  local algorithm = class:new(self.graph)
  algorithm:run()
end



function SugiyamaModularLayered:restoreCycles()
  for edge in table.value_iter(self.graph.edges) do
    edge.reversed = false
  end
end



function SugiyamaModularLayered:postprocess()
end



function SugiyamaModularLayered:loadSubAlgorithm(step, name)

  -- make sure there are no spaces in the file name
  name = name:gsub(' ', '')

  --Sys:log('pre   classname: ' .. classname)
  --Sys:log('escaped name:    ' .. escaped_name)

  local classname = step .. name
  local filename = 'pgfgd-subalgorithm-' .. classname .. '.lua'

  --Sys:log('load class = ' .. classname .. ', file = ' .. filename)

  pgf.load(filename, 'tex', false)

  --Sys:log('final classname: ' .. classname)
  --Sys:log('final filename:  ' .. filename)

  return classname, pgf.graphdrawing[classname]
end



function SugiyamaModularLayered:dumpRanking(prefix, title)
  local ranks = self.ranking:getRanks()
  Sys:log(prefix .. title)
  for rank in table.value_iter(ranks) do
    local nodes = self.ranking:getNodes(rank)
    local str = prefix .. '  rank ' .. rank .. ':'
    local str = table.combine_values(nodes, function (str, node)
      return str .. ' ' .. node.name .. ' (' .. self.ranking:getRankPosition(node) .. ')'
    end, str)
    Sys:log(str)
  end
end
