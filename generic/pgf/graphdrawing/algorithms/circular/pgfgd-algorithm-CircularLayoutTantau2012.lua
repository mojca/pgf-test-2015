-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/algorithms/misc/pgfgd-algorithm-CircularLayoutTantau2012.lua,v 1.3 2012/04/05 10:04:13 tantau Exp $


--- A circular layout
--
-- This layout places the nodes on a circle, starting at the growth
-- direction.  
--
-- The objective is that nodes are ideally spaced at a distance
-- (measured on the circle) of "sibling distance", but with a minimum
-- spacing of "sibling sep" and a minimum radius.
--
-- The order of the nodes will be the order they are encountered, the
-- edges actually play no role.

graph_drawing_algorithm { 
  name = 'CircularLayoutTantau2012',
  properties = {
    growth_direction = 180
  },
  graph_parameters = {
    minimum_radius = {'circular layout/radius', tonumber}
  }
}

function CircularLayoutTantau2012:run()
  local n = #self.graph.nodes

  local sib_dists = self:computeSiblingDistances ()
  local radii = self:computeNodeRadii()
  local diam, adjusted_radii = self:adjustNodeRadii(sib_dists, radii)
  
  -- Compute total necessary length. For this, iterate over all 
  -- consecutive pairs and keep track of the necessary space for 
  -- this node. We imagine the nodes to be aligned from left to 
  -- right in a line. 
  local carry = 0
  local positions = {}
  local n = #self.graph.nodes
  local function wrap(i) return (i-1)%n + 1 end
  local ideal_pos = 0
  for i = 1,n do
    positions[i] = ideal_pos + carry
    ideal_pos = ideal_pos + sib_dists[i]
    local sibling_sep =   self.graph.nodes[i]:getOption('/graph drawing/sibling post sep', self.graph)
                        + self.graph.nodes[wrap(i+1)]:getOption('/graph drawing/sibling pre sep', self.graph)
    local arc = sibling_sep + adjusted_radii[i] + adjusted_radii[wrap(i+1)] 
    local needed = carry + arc
    local dist = math.sin( arc/diam ) * diam
    needed = needed + math.max ((radii[i] + radii[wrap(i+1)]+sibling_sep)-dist, 0)
    carry = math.max(needed-sib_dists[i],0)    
  end
  local length = ideal_pos + carry

  local radius = length / (2 * math.pi)
  for i,node in ipairs(self.graph.nodes) do
      node.pos:set{
	x = radius * math.cos(2 * math.pi * positions[i] / length),
	y = radius * math.sin(2 * math.pi * positions[i] / length)
      }
   end
end


function CircularLayoutTantau2012:computeSiblingDistances()
  local sib_dists = {}
  local sum_length = 0
  local nodes = self.graph.nodes
  for i=1,#nodes do
     sib_dists[i] = nodes[i]:getOption('/graph drawing/sibling distance', self.graph)
     sum_length = sum_length + sib_dists[i]
  end

  local missing_length = self.minimum_radius * 2 * math.pi - sum_length
  if missing_length > 0 then
     -- Ok, the sib_dists to not add up to the desired minimum value. 
     -- What should we do? Hmm... We increase all by the missing amount:
     for i=1,#nodes do
	sib_dists[i] = sib_dists[i] + missing_length/#nodes
     end
  end

  sib_dists.total = math.max(self.minimum_radius * 2 * math.pi, sum_length)

  return sib_dists
end


function CircularLayoutTantau2012:computeNodeRadii()
  local radii = {}
  for i,n in pairs(self.graph.nodes) do
    if n.tex.shape == "circle" or n.tex.shape == "ellipse" then
      radii[i] = math.max(n:getTexWidth(),n:getTexHeight())/2
    else
      local w, h = n:getTexWidth(), n:getTexHeight()
      radii[i] = math.sqrt(w*w + h*h)/2
    end
  end
  return radii
end


function CircularLayoutTantau2012:adjustNodeRadii(sib_dists,radii)
  local total = 0
  for i=1,#radii do
    total = total + 2*radii[i] 
            + self.graph.nodes[i]:getOption('/graph drawing/sibling post sep', self.graph)
	    + self.graph.nodes[i]:getOption('/graph drawing/sibling pre sep', self.graph)
  end
  total = math.max(total, sib_dists.total)
  local diam = total/(math.pi)

  -- Now, adjust the radii:
  local adjusted_radii = {}
  for i=1,#radii do
    adjusted_radii[i] = (math.pi - 2*math.acos(radii[i]/diam))*diam/2
  end
  
  return diam, adjusted_radii
end