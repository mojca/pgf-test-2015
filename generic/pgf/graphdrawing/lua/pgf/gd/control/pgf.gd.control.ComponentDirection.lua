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
-- @section subsubsection {Arranging Components in a Certain Direction}

local _

---

declare {
  key = "component direction",
  type = "direction",
  initial = "0",

  documentation = [["  
       The \meta{angle} is used to determine the relative position of each
       component relative to the previous one. The direction need not be a
       multiple of |90|.
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle},
                     component direction=left]
         { a, b, c -- d -- e, f -- g };
       \end{codeexample}
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle},
                     component direction=10]
         { a, b, c -- d -- e, f -- g };
       \end{codeexample}
         As usual, you can use texts like |up| or |right| instead of a
         number.
      
         As the example shows, the direction only has an influence on the
         relative positions of the components, not on the direction of growth
         inside the components. In particular, the components are not rotated
         by this option in any way. You can use the |grow| option or |orient|
         options to orient individual components:
       \begin{codeexample}[]
       \tikz \graph [tree layout, nodes={inner sep=1pt,draw,circle},
                     component direction=up]
         { a, b, c [grow=right] -- d -- e, f[grow=45] -- g };
       \end{codeexample}
  "]]
}


return Components