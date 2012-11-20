-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header: /cvsroot/pgf/pgf/generic/pgf/graphdrawing/lua/pgf/gd/trees/pgf.gd.trees.lua,v 1.1 2012/04/19 15:22:29 tantau Exp $


local declare       = require "pgf.gd.interface.InterfaceToAlgorithms".declare


  

---
-- @section subsubsection {Ordering the Components}
--
-- The different connected components of the graph are collected in a
-- list. The ordering of the nodes in this list can be configured using
-- the following key.

local _


---

declare {
  key = "component order",
  type = "string",
  initial = "by first specified node",

  documentation = [["  
       The following values are permissible for \meta{strategy}
       \begin{itemize}
       \item \declare{|by first specified node|}
      
         The components are ordered ``in the way they appear in the input
         specification of the graph''. More precisely, for each component
         consider the node that is first encountered in the description
         of the graph. Order the components in the same way as these nodes
         appear in the graph description.
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle}]
       { a, b, c, f -- g, c -- d -- e };
       \end{codeexample}
         \item \declare{|increasing node number|}
        
           The components are ordered by increasing number of nodes. For
           components with the same number of nodes, the first node in each
           component is considered and they are ordered according to the
           sequence in which these nodes appear in the input.
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle},
                     component order=increasing node number]
       { a, b, c -- d -- e, f -- g };
       \end{codeexample}
         \item \declare{|decreasing node number|}
           As above, but in decreasing order.  
       \end{itemize}
      
       @param strategy A string specifying a strategy.
  "]]
}  
       
       
---

declare {
  key = "small components first",
  { key = "component order", value = "increasing node number" },

  documentation = [["  
       A shorthand for |component order=increasing node number|.
   "]]
 }
  
---

declare {
  key = "large components first",
  { key = "component order", value = "decreasing node number" },

  documentation = [["  
       A shorthand for |component order=decreasing node number|.
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle},
                     large components first]
       { a, b, c -- d -- e, f -- g };
       \end{codeexample}
  "]]
}  


return Components