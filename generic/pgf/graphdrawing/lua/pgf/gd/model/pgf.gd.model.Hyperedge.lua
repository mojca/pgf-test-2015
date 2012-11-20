-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/control/pgf.gd.control.Sublayouts.lua,v 1.2 2012/09/27 11:45:21 tantau Exp $



--- 
-- @section subsection {Hyperedges}
--

local _

-- Includes

local declare    = require "pgf.gd.interface.InterfaceToAlgorithms".declare


---

declare {
  key = "hyper",
  layer = -10,

  documentation = [["  
       A \emph{hyperedge} of a graph does not connect just two nodes, but
       is any subset of the node set (although a normal edge is also a
       hyperedge  that happens to contain just two nodes). Internally, a
       collection of kind |hyper| is created.   
       
       Currently, there is no default renderer for hyper edges. 
      
      \begin{codeexample}[code only]
      \graph {
        % The nodes:
        a, b, c, d;
        
        % The edges:
        {[hyper] a,b,c};
        {[hyper] b,c,d};
        {[hyper] a,c};
        {[hyper] d}
      };
      \end{codeexample}
 "]]
}
    
-- Done 

return Hyperedge