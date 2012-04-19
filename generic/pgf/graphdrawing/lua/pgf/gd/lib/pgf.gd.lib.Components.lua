-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/lib/pgf-gd-lib-Components.lua,v 1.3 2012/04/19 13:49:07 tantau Exp $



--- The Components class is a singleton object.
--
-- Its methods provide methods for handling components, include their packing code. 

local Components = {}


-- Namespace
local lib     = require "pgf.gd.lib"
lib.Components = Components

-- Imports

local Cluster = require "pgf.gd.model.Cluster"
local Node    = require "pgf.gd.model.Node"



--- Decompose a graph into its components
--
-- @param graph A to-be-decomposed graph
--
-- @return An array of graph objects that represent the connected components of the graph. 

function Components:decompose (graph)

  -- The list of connected components (node sets)
  local components = {}
  
  -- Remember, which graphs have already been visited
  local visited = {}
  
  for i,n in ipairs(graph.nodes) do
    if not visited[n] then
      -- Start a depth-first-search of the graph, starting at node n:
      local stack = { n }
      local nodes = {}
      
      while #stack >= 1 do
	local tos = stack[#stack]
	stack[#stack] = nil -- pop
	
	if not visited[tos] then
	  -- Visit pos:
	  nodes[#nodes+1] = tos
	  visited[tos] = true
	  
	  for _,e in ipairs(tos.edges) do
	    for _,neighbor in ipairs(e.nodes) do
	      if not visited[neighbor] then
		stack[#stack+1] = neighbor
	      end
	    end
	  end
	end
      end
      
      -- Ok, nodes will now contain all vertices reachable from n.
      components[#components+1] = nodes
    end
  end
  
  -- Case 1: Only one components -> do not do anything
  if #components < 2 then
    return { graph }
  end
  
  -- Case 2: Multiple components
  local graphs = {}
  
  for i = 1,#components do
    -- Build a graph containing only the nodes in the components
    local subgraph = graph:copy()
    
    subgraph.nodes = components[i]
    
    for _,c in ipairs(graph.clusters) do
      local new_c = Cluster:new(c:getName())
      subgraph:addCluster(new_c)
      for _,n in ipairs(c.nodes) do
	if subgraph:findNode(n.name) then
	  new_c:addNode(n)
	end
      end
    end
    
    -- add edges
    local edges = {}
    for _,n in ipairs(subgraph.nodes) do
      for _,e in ipairs(n.edges) do
	edges[e] = true
      end
    end
    
    for e in pairs(edges) do
      subgraph.edges[#subgraph.edges + 1] = e
    end
    
    table.sort (subgraph.nodes, function (a, b) return a.index < b.index end)
    table.sort (subgraph.edges, function (a, b) return a.index < b.index end)
    
    graphs[#graphs + 1] = subgraph
  end
  
  return graphs
end




--- Handling of component order
--
-- Components are ordered according to a function that is stored in
-- a key of the Components:component_ordering_functions table (subject
-- to change...) whose name is the graph option /graph
-- drawing/component order. 
--
-- @param graph A graph
-- @param subgraphs A list of to-be-sorted subgraphs

function Components:sort(graph, subgraphs)
  local component_order = graph:getOption('/graph drawing/component order')

  if component_order then
    local f = Components.component_ordering_functions[component_order]
    if f then
      table.sort (subgraphs, f)
    end
  end
end


-- Right now, we hardcode the functions here. Perhaps make this
-- dynamic in the future. Could easily be done on the tikzlayer,
-- acutally. 

Components.component_ordering_functions = {
  ["increasing node number"] = 
    function (g,h) 
      if #g.nodes == #h.nodes then
	return g.nodes[1].index < h.nodes[1].index
      else
	return #g.nodes < #h.nodes 
      end
    end,
  ["decreasing node number"] = 
    function (g,h) 
      if #g.nodes == #h.nodes then
	return g.nodes[1].index < h.nodes[1].index
      else
	return #g.nodes > #h.nodes 
      end
    end,
  ["by first specified node"] = nil,
}




local function prepare_bounding_boxes(nodes, angle, sep)

  for _,n in ipairs(nodes) do
    -- Fill the bounding box field,
    local bb = {}

    local corners
    if n.kind == "node" then
      corners = {
	{ x = n.tex.minX + n.pos.x, y = n.tex.minY + n.pos.y },
	{ x = n.tex.minX + n.pos.x, y = n.tex.maxY + n.pos.y },
	{ x = n.tex.maxX + n.pos.x, y = n.tex.minY + n.pos.y },
	{ x = n.tex.maxX + n.pos.x, y = n.tex.maxY + n.pos.y },
      }
    else
      corners = { {x = n.pos.x, y = n.pos.y} }
    end
	
    bb.min_x = math.huge
    bb.max_x = -math.huge
    bb.min_y = math.huge
    bb.max_y = -math.huge
	
    for i=1,#corners do
      local x =  corners[i].x*math.cos(angle) + corners[i].y*math.sin(angle)
      local y = -corners[i].x*math.sin(angle) + corners[i].y*math.cos(angle)
      
      bb.min_x = math.min (bb.min_x, x)
      bb.max_x = math.max (bb.max_x, x)
      bb.min_y = math.min (bb.min_y, y)
      bb.max_y = math.max (bb.max_y, y)
    end

    -- Enlarge by sep:
    bb.min_x = bb.min_x - sep
    bb.max_x = bb.max_x + sep
    bb.min_y = bb.min_y - sep
    bb.max_y = bb.max_y + sep
    
    bb.center_x =  n.pos.x*math.cos(angle) + n.pos.y*math.sin(angle)
    bb.center_y = -n.pos.x*math.sin(angle) + n.pos.y*math.cos(angle)

    n.component_info = bb
  end
end



--- Pack components
--
-- Rearranges the positions of nodes. 
-- See Section~\ref{subsection-gd-component-packing} for details.
--
-- @param graph The graph
-- @param components A list of components

function Components:pack(graph, components)
  
  -- Step 1: Preparation, rotation to target direction
  local sep = tonumber(graph:getOption('/graph drawing/component sep'))
  local angle = tonumber(graph:getOption('/graph drawing/component direction'))/180*math.pi

  local vnodes = {} -- This is just a "unique index".

  for _,c in ipairs(components) do
    -- Setup the lists of to-be-considered nodes
    local nodes = {}
    for _,n in ipairs(c.nodes) do
      nodes [#nodes + 1] = n
    end
    for _,e in ipairs(c.edges) do
      for _,p in ipairs(e.bend_points) do
	nodes [#nodes + 1] = Node:new { pos = p, kind = "dummy" }
      end
    end
    c[vnodes] = nodes

    prepare_bounding_boxes(c[vnodes], angle, sep/2)
  end
  
  local x_shifts = { 0 }
  local y_shifts = {}
  
  -- Step 2: Vertical alignment
  for i,c in ipairs(components) do
    local max_max_y = -math.huge
    local max_center_y = -math.huge
    local min_min_y = math.huge
    local min_center_y = math.huge
    for _,n in ipairs(c.nodes) do
      max_max_y = math.max(n.component_info.max_y, max_max_y)
      max_center_y = math.max(n.component_info.center_y, max_center_y)
      min_min_y = math.min(n.component_info.min_y, min_min_y)
      min_center_y = math.min(n.component_info.center_y, min_center_y)
    end
    
    local valign = graph:getOption('/graph drawing/component align')
    local line
    if valign == "counterclockwise bounding box" then
      line = max_max_y
    elseif valign == "counterclockwise" then
      line = max_center_y
    elseif valign == "center" then
      line = (max_max_y + min_min_y) / 2
    elseif valign == "clockwise" then
      line = min_center_y
    elseif valign == "first node" then
      line = c.nodes[1].component_info.center_y
    else 
      line = min_min_y
    end

    for _,n in ipairs(c.nodes) do
      if n:getOption('/graph drawing/align here') then
	line = n.component_info.center_y
	break
      end
    end
    
    y_shifts[i] = -line

    -- Adjust nodes:
    for _,n in ipairs(c[vnodes]) do
      local bb = n.component_info
      bb.min_y = bb.min_y - line
      bb.max_y = bb.max_y - line
      bb.center_y = bb.center_y - line
      n.component_info = bb
    end
  end

  -- Step 3: Horizontal alignment
  local y_values = {}

  for _,c in ipairs(components) do
    for _,n in ipairs(c[vnodes]) do
      y_values[#y_values+1] = n.component_info.min_y
      y_values[#y_values+1] = n.component_info.max_y
      y_values[#y_values+1] = n.component_info.center_y
    end
  end
  
  table.sort(y_values)
  
  local y_ranks = {}
  local right_face = {}
  for i=1,#y_values do
    y_ranks[y_values[i]] = i
    right_face[i] = -math.huge
  end
  
  for i=1,#components-1 do
    -- First, update right_face:
    local touched = {}
    for _,n in ipairs(components[i][vnodes]) do
      local bb = n.component_info
      local border = bb.max_x
      
      for i=y_ranks[bb.min_y],y_ranks[bb.max_y] do
	touched[i] = true
	right_face[i] = math.max(right_face[i], border)
      end
    end
    
    -- Fill up the untouched entries:
    local right_max = -math.huge
    for i=1,#y_values do
      if not touched[i] then
	-- Search for next and previous touched
	local interpolate = -math.huge
	for j=i+1,#y_values do
	  if touched[j] then
	    interpolate = math.max(interpolate,right_face[j] - (y_values[j] - y_values[i]))
	    break
	  end
	end
	for j=i-1,1,-1 do
	  if touched[j] then
	    interpolate = math.max(interpolate,right_face[j] - (y_values[i] - y_values[j]))
	    break
	  end
	end
	right_face[i] = interpolate
      end
      right_max = math.max(right_max, right_face[i])
    end

    -- Second, compute the left face
    local touched = {}
    local left_face = {}
    for i=1,#y_values do
      left_face[i] = math.huge
    end
    for _,n in ipairs(components[i+1][vnodes]) do
      local bb = n.component_info
      local border = bb.min_x

      for i=y_ranks[bb.min_y],y_ranks[bb.max_y] do
	touched[i] = true
	left_face[i] = math.min(left_face[i], border)
      end
    end
    
    -- Fill up the untouched entries:
    local left_min = math.huge
    for i=1,#y_values do
      if not touched[i] then
	-- Search for next and previous touched
	local interpolate = math.huge
	for j=i+1,#y_values do
	  if touched[j] then
	    interpolate = math.min(interpolate,left_face[j] + (y_values[j] - y_values[i]))
	    break
	  end
	end
	for j=i-1,1,-1 do
	  if touched[j] then
	    interpolate = math.min(interpolate,left_face[j] + (y_values[i] - y_values[j]))
	    break
	  end
	end
	left_face[i] = interpolate
      end
      left_min = math.min(left_min, left_face[i])
    end

    -- Now, compute the shift.
    local shift = -math.huge

    if graph:getOption('/graph drawing/component packing') == "rectangular" then
      shift = right_max - left_min
    else
      for i=1,#y_values do
	shift = math.max(shift, right_face[i] - left_face[i])
      end
    end
    
    -- Adjust nodes:
    x_shifts[i+1] = shift
    for _,n in ipairs(components[i+1][vnodes]) do
      local bb = n.component_info
      bb.min_x = bb.min_x + shift
      bb.max_x = bb.max_x + shift
      bb.center_x = bb.center_x + shift
      n.component_info = bb
    end
  end
  
  -- Now, rotate shifts
  for i,c in ipairs(components) do
    local x =  x_shifts[i]*math.cos(-angle) + y_shifts[i]*math.sin(-angle)
    local y = -x_shifts[i]*math.sin(-angle) + y_shifts[i]*math.cos(-angle)
    
    for _,n in ipairs(c[vnodes]) do
      n.pos.x = n.pos.x + x
      n.pos.y = n.pos.y + y
    end

    -- Done...
    c[vnodes] = nil
  end
end


-- Done

return Components