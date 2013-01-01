-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/ogdf/layered/SugiyamaLayout.lua,v 1.1 2012/12/30 00:20:50 tantau Exp $


---
-- @section subsection {The Sugiyama Method}
--

local _


local declare = require "pgf.gd.interface.InterfaceToAlgorithms".declare

---
declare {
  key = "SugiyamaLayout",
  algorithm_written_in_c = "pgf.gd.ogdf.c.CLibrary.sugiyama_layout",
  preconditions = {
    connected = true
  },
  postconditions = {
    upward_oriented = true
  },
  includes = {
    "#include <ogdf/layered/SugiyamaLayout.h>"
  },
  code = [[
      SugiyamaLayout SL;
      
      if (is_module_set<RankingModule>())
        SL.setRanking(new_module<RankingModule>());
	
      if (is_module_set<TwoLayerCrossMin>())
        SL.setCrossMin(new_module<TwoLayerCrossMin>());
	
      SL.call(graph_attributes);

      // Flip:
      node v;
      forall_nodes (v, graph) graph_attributes.x(v) = -graph_attributes.x(v);
  ]],
  summary = "The OGDF implementation of the Sugiyama algorithm.",
  documentation = [["  
      This layout represents a customizable
      implementation of Sugiyama's layout algorithm.
      The implementation used in |SugiyamaLayout| is based on the
      following publications:

      \begin{itemize}
      \item Emden R. Gansner, Eleftherios Koutsofios, Stephen
        C. North, Kiem-Phong Vo: A technique for drawing directed
        graphs. \emph{IEEE Trans. Software Eng.} 19(3):214--230, 1993. 
      \item Georg Sander: \emph{Layout of compound directed graphs.}
        Technical Report, Universität des Saarlandes, 1996. 
      \end{itemize}
  "]],
}


---
declare { 
  key = "SugiyamaLayout.runs",
  type = "number",
  initial = "15",
  summary = "Determines, how many times the crossing minimization is repeated.",
  documentation = [["
      Each repetition (except for the first) starts with
      randomly permuted nodes on each layer. Deterministic behaviour can
      be achieved by setting |SugiyamaLayout.runs| to 1.
  "]], 
}

---
declare { 
  key = "SugiyamaLayout.transpose",
  type = "boolean",
  initial = "true",
  summary = [["Determines whether the transpose step is performed
      after each 2-layer crossing minimization; this step tries to
      reduce the number of crossings by switching neighbored nodes on
      a layer."]] 
}
    
---
declare {
  key = "SugiyamaLayout.fails",
  type = "number",
  initial = "4",
  summary = [["The number of times that the number of crossings may
      not decrease after a complete top-down bottom-up traversal,
      before a run is terminated."]]
}
    
    
-- Load modules:
    
require "pgf.gd.ogdf.layered.RankingModule"
require "pgf.gd.ogdf.layered.TwoLayerCrossMin"
require "pgf.gd.ogdf.layered.AcyclicSubgraphModule"
-- require "pgf.gd.ogdf.layered.HierarchyLayoutModule" -- missing...
    