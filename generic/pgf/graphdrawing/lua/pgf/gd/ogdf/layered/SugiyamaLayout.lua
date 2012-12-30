-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/examples/SimpleDemo.lua,v 1.2 2012/11/30 12:00:52 tantau Exp $


---
-- @section subsubsection {The Sugiyama Method}

local section


local declare = require "pgf.gd.interface.InterfaceToAlgorithms".declare

---
declare {
  key = "SugiyamaLayout",
  algorithm_written_in_c = "pgf.gd.ogdf.c.CLibrary.sugiyama_layout",
  postconditions = { upward_oriented = true },
  includes = {
    "#include <ogdf/layered/SugiyamaLayout.h>",
    "#include <ogdf/layered/OptimalRanking.h>",
    "#include <ogdf/layered/MedianHeuristic.h>"
  },
  code = [[
      SugiyamaLayout SL;
      SL.setRanking(new OptimalRanking);
      SL.setCrossMin(new MedianHeuristic);
      SL.call(graph_attributes);
  ]],
  summary = "The OGDF implementation of the Sugiyama algorithm.",
  documentation = [["  
      ...
  "]],
}
    
