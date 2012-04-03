-- Copyright 2010 by Renée Ahrens, Olof Frahm, Jens Kluttig, Matthias Schulz, Stephan Schuster
-- Copyright 2011 by Jannis Pohlmann
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/core/lualayer/pgflibrarygraphdrawing-graph.lua,v 1.13 2012/03/29 19:38:38 tantau Exp $

-- This file defines a graph class, which later represents user created
-- graphs.

pgf.module("pgf.graphdrawing")



Graph = Box:new()
Graph.__index = Graph



--- Creates a new graph.
--
-- @param values  Values to override default graph settings.
--                The following parameters can be set:\par
--                |nodes|: The nodes of the graph.\par
--                |edges|: The edges of the graph.\par
--                |clusters|: The node clusters of the graph.\par
--                |pos|: Initial position of the graph.\par
--                |options|: A table of node options passed over from \tikzname.
--                |flags|: A table of flags for use by graph algorithms.
--
-- @return A newly-allocated graph.
--
function Graph:new(values)
  local defaults = {
    nodes = {},
    edges = {},
    clusters = {},
    options = {}
  }
  setmetatable(defaults, Graph)
  local result = table.custom_merge(values, defaults)
  return result
end



--- Sets the graph option \meta{name} to \meta{value}.
--
-- @param name Name of the option to be changed.
-- @param value New value for the graph option \meta{name}.
--
function Graph:setOption(name, value)
  self.options[name] = value
end



--- Returns the value of the graph option \meta{name}.
--
-- @param name Name of the option.
--
-- @return The value of the graph option \meta{name} or |nil|.
--
function Graph:getOption(name)
   return self.options[name] or Interface.defaultGraphParameters[name]
end



--- Merges the given options into the options of the graph.
--
-- @see table.custom_merge
--
-- @param options The options to be merged.
--
function Graph:mergeOptions(options)
 self.options = table.custom_merge(options, self.options)
end



--- Creates a shallow copy of a graph.
--
-- The nodes and edges of the original graph are not preserved in the copy.
--
-- @return A shallow copy of the graph.
--
function Graph:copy ()
   return Graph:new({options = self.options})
end


--- Adds a node to the graph.
--
-- @param node The node to be added.
--
function Graph:addNode(node)
   -- only add the node if it's not included in the graph yet
   if not self:findNode(node.name) then
      -- Does the node have an index, yet?
      if not node.index then
	 node.index = #self.nodes + 1
      end
      
      table.insert(self.nodes, node)
      
      if node.tex.maxY and node.tex.maxX and node.tex.minY and node.tex.minX then
	 node.height = string.sub(node.tex.maxY, 0, string.len(node.tex.maxY)-2) 
	               - string.sub(node.tex.minY, 0, string.len(node.tex.minY)-2)
      
         node.width = string.sub(node.tex.maxX,0,string.len(node.tex.maxX)-2)
                       - string.sub(node.tex.minX,0,string.len(node.tex.minX)-2)
      end

      assert(node.height >= 0)
      assert(node.width >= 0)
   end
end



--- If possible, removes a node from the graph and returns it.
--
-- @param node The node to remove.
--
-- @return The removed node or |nil| if it was not found in the graph.
--
function Graph:removeNode(node)
  local index = table.find_index(self.nodes, function (other) 
    return other.name == node.name 
  end)
  if index then
    table.remove(self.nodes, index)
    return node
  else
    return nil
  end
end



--- If possible, looks up the node with the given name in the graph.
--
-- @param name Name of the node to look up.
--
-- @return The node with the given name or |nil| if it was not found in the graph.
--
function Graph:findNode(name)
  return self:findNodeIf(function (node) return node.name == name end)
end



--- Looks up the first node for which the function \meta{test} returns |true|.
--
-- @param test A function that takes one parameter (a |Node|) and returns 
--             |true| or |false|.
--
-- @return The first node for which \meta{test} returns |true|.
--
function Graph:findNodeIf(test)
  return table.find(self.nodes, test)
end



--- Like removeNode, but also deletes all adjacent edges of the removed node.
--
-- This function also removes the deleted adjacent edges from all neighbours
-- of the removed node.
--
-- @param node The node to be deleted together with its adjacent edges.
--
-- @return The removed node or |nil| if the node was not found in the graph.
--
function Graph:deleteNode(node)
  local node = self:removeNode(node)
  if node then
    for edge in table.value_iter(node.edges) do
      self:removeEdge(edge)
      for other_node in table.value_iter(edge.nodes) do
        if other_node.name ~= node.name then
          other_node:removeEdge(edge)
        end
      end
    end
    node.edges = {}
  end
  return node
end



-- Checks whether the edge already exists in the graph and returns it if possible.
--
-- @param edge Edge to search for.
--
-- @return The edge if it was found in the graph, |nil| otherwise.
--
function Graph:findEdge(edge)
  return table.find(self.edges, function (other) return other == edge end)
end



--- Adds an edge to the graph.
--
-- @param edge The edge to be added.
--
function Graph:addEdge(edge)
   if not edge.index then
      edge.index = #self.edges + 1
   end

   table.insert(self.edges, edge)
end



--- If possible, removes an edge from the graph and returns it.
--
-- @param edge The edge to be removed.
--
-- @return The removed edge or |nil| if it was not found in the graph.
--
function Graph:removeEdge(edge)
  local index = table.find_index(self.edges, function (other) return other == edge end)
  if index then
    table.remove(self.edges, index)
    return edge
  else
    return nil
  end
end



--- Like removeEdge, but also removes the edge from its adjacent nodes.
--
-- @param edge The edge to be deleted.
--
-- @return The removed edge or |nil| if it was not found in the graph.
--
function Graph:deleteEdge(edge)
  local edge = self:removeEdge(edge)
  if edge then
    for node in table.value_iter(edge.nodes) do
      node:removeEdge(edge)
    end
  end
  return edge
end



--- Removes an edge between two nodes and also removes it from these nodes.
--
-- @param from Start node of the edge.
-- @param to   End node of the edge.
--
-- @return The deleted edge.
--
function Graph:deleteEdgeBetweenNodes(from, to)
  -- try to find the edge
  local edge = table.find(self.edges, function (edge)
    return edge.nodes[1] == from and edge.nodes[2] == to
  end)

  -- delete and return the edge
  if edge then
    return self:deleteEdge(edge)
  else
    return nil
  end
end



--- Creates and adds a new edge to the graph. 
--
-- @param first_node   The first node of the new edge.
-- @param second_node  The second node of the new edge.
-- @param direction    The direction of the new edge. Possible values are
--                     \begin{itemize}
--                     \item |Edge.UNDIRECTED|,
--                     \item |Edge.LEFT|,
--                     \item |Edge.RIGHT|,
--                     \item |Edge.BOTH| and
--                     \item |Edge.NONE| (for invisible edges).
--                     \end{itemize}
-- @param edge_nodes   A string of \tikzname\ edge nodes that needs to be passed 
--                     back to the \TeX layer unmodified.
-- @param options      The options of the new edge.
-- @param tikz_options A table of \tikzname\ options to be used by graph drawing
--                     algorithms to treat the edge in special ways.
--
-- @return The newly created edge.
--
function Graph:createEdge(first_node, second_node, direction, edge_nodes, options, tikz_options)
  local edge = Edge:new{
    direction = direction, 
    edge_nodes = edge_nodes,
    options = options, 
    tikz_options = tikz_options
  }
  edge:addNode(first_node)
  edge:addNode(second_node)
  self:addEdge(edge)
  return edge
end



--- Returns the cluster with the given name or |nil| if no such cluster exists.
--
-- @param name Name of the node cluster to look up.
--
-- @return The cluster with the given name or |nil| if no such cluster is defined.
--
function Graph:findClusterByName(name)
  return table.find(self.clusters, function (cluster)
    return cluster:getName() == name
  end)
end



--- Tries to add a cluster to the graph. Returns whether or not this was successful.
--
-- Clusters are supposed to have unique names. This function will add the given
-- cluster only if there is no cluster with this name already. It returns |true|
-- if the cluster was added and |false| otherwise.
--
-- @param cluster Cluster to add to the graph.
--
-- @return |true| if the cluster was added successfully, |false| otherwise.
--
function Graph:addCluster(cluster)
  if not self:findClusterByName(cluster:getName()) then
    table.insert(self.clusters, cluster)
  end
end





--- Computes the pseudo diameter of the graph.
--
-- The diameter of a graph is the maximum of the shortest paths between
-- any pair of nodes in the graph. A pseudo diameter is an approximation
-- of the diameter that is computed by picking a starting node |u| and
-- finding a node |v| that is farthest away from |u| and has the smallest
-- degree of all nodes that have the same distance to |u|. The algorithm
-- continues with |v| as the new starting node and iteratively tries
-- to find an end node that is generates a larger pseudo diameter.
-- It terminates as soon as no such end node can be found.
--
-- @return The pseudo diameter of the graph.
-- @return The start node of the corresponding approximation of a maximum
--         shortest path.
-- @return The end node of that path.
--
function Graph:getPseudoDiameter()
  -- find a node with minimum degree
  local start_node = table.combine_values(self.nodes, function (min, node)
    if node:getDegree() < min:getDegree() then
      return node
    else
      return min
    end
  end, self.nodes[1])

  assert(start_node)

  local old_diameter = 0
  local diameter = 0
  local end_node = nil

  while true do
    local distance, levels = algorithms.dijkstra(self, start_node)

    -- the number of levels is the same as the distance of the nodes
    -- in the last level to the start node
    old_diameter = diameter
    diameter = #levels

    -- abort if the diameter could not be improved
    if diameter == old_diameter then
      end_node = levels[#levels][1]
      break
    end

    -- select the node with the smallest degree from the last level as
    -- the start node for the next iteration
    start_node = table.combine_values(levels[#levels], function (min, node)
      if node:getDegree() < min:getDegree() then
        return node
      else
        return min
      end
    end, levels[#levels][1])

    assert(start_node)
  end

  assert(start_node)
  assert(end_node)

  return diameter, start_node, end_node
end



--- Returns a string representation of this graph including all nodes and edges.
--
-- @ignore This should not appear in the documentation.
--
-- @return Graph as string.
--
function Graph:__tostring()
  local tmp = Graph.__tostring
  Graph.__tostring = nil
  local result = "Graph<" .. tostring(self) .. ">(("
  Graph.__tostring = tmp

  local first = true
  for node in table.value_iter(self.nodes) do
    if first then first = false else result = result .. ", " end
    result = result .. tostring(node)
  end
  result = result .. "), ("
  first = true
  for edge in table.value_iter(self.edges) do
    if first then first = false else result = result .. ", " end
    result = result .. tostring(edge)
  end

  return result .. "))"
end
