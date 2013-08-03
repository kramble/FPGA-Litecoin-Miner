#!/usr/bin/env python

"""
  Copyright (c) 2007 Jan-Klaas Kollhof

  This file is part of jsonrpc.

  jsonrpc is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation; either version 2.1 of the License, or
  (at your option) any later version.

  This software is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with this software; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
"""


import unittest
import os


from jsonrpc import _tests

if __name__ == "__main__":

    testPath = os.path.split(_tests.__file__)[0]
    testModules = []
    for fileName in os.listdir(testPath):
        if fileName[-3:] == '.py' and fileName != '__init__.py':
            testModules.append('jsonrpc._tests.%s' % fileName[:-3])

    suite = unittest.TestLoader().loadTestsFromNames(testModules)

    unittest.TextTestRunner(verbosity=5).run(suite)
    
