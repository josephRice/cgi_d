module cgi.router;
/*****************************************************************************
 * package: cgi
 * module cgi.router
 * File: router.d
 * Description:  utility d module that allows conditional execution of classes that implement the ROUTE interface by 
 * 				 matching a string to the CGI PATH_INFO or QUERY_STRING.
 * Author: Joseph M. Rice (ricejm01@gmail.com)
 * Date: Thu Nov 13 13:59:10 EST 2015
 *
 *MIT License
 *
 *Copyright (c) 2014-2016 Joseph M. Rice <ricejm01@gmail.com>
 *
 *Permission is hereby granted, free of charge, to any person obtaining a copy
 *of this software and associated documentation files (the "Software"), to deal
 *in the Software without restriction, including without limitation the rights
 *to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *copies of the Software, and to permit persons to whom the Software is
 *furnished to do so, subject to the following conditions:
 *
 *The above copyright notice and this permission notice shall be included in all
 *copies or substantial portions of the Software.
 *
 *THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *SOFTWARE. 
 ***************************************************************************/

import cgi.cgi;
import std.algorithm;

class RouterException : Exception
{
	this(string msg, string file = __FILE__, ulong line = cast(ulong)__LINE__, Throwable next = null)
	{
		super(msg,file,line,next);
	}
}

/**
 * interface ROUTE
 *
 * interface class that allows you to create classes to be used 
 * with the ROUTER class.   
 */
interface ROUTE 
{
	/**
	 * main method that will perform the actions/purpose of your class.   
	 * 
	 */
	void run(CGI cgi);
}

/**
 * class ROUTER
 *
 * Description: handle path_info or CGI query string information to logically
 *      determine a cgi application flow control.  This class allows you use develop
 *		a restful api, and then serve up content based upon the path_info or CGI 
 *		query string information.   IE.  "/foo/" or "?func=foo"
 */
class ROUTER
{
	CGI cgi;
	private string path;

	this(CGI cgi) {
		// Constructor code
		if (!cgi) throw new RouterException("cgi environment is not initialized or is null");
		this.cgi = cgi;
	}

	/**
  	 * run a route based off the path_info envirement variable
	 *
	 * returns true if the a cgi.PATH_INFO starts with the path variable 
	 */	 
	bool runRoute(string path, ROUTE route) {
		ulong i = 0;
		bool pathMatch = false;

		if (!path || path.length == 0) throw new RouterException("Un-initialized or null path");

		this.path = path;

		if (!route) throw new RouterException("Un-initialized or null route");

		if (startsWith(cgi.PATH_INFO,path)) pathMatch = true;

		if (pathMatch) route.run(cgi);

		return pathMatch;
	}

	/**
	 * Run a route based off if a cgi variable exists in a query string.
	 *
	 * returns true if the name variable exists in the cgi query string.
	 */
	bool runQueryRoute(string name, ROUTE route) {
		bool match = false;

		if (!route) throw new RouterException("Un-initialized or null route");

		if (cgi.exists(name)) {
			route.run(cgi);
			match = true;
		}

		return match;
	}

	string basePath() {
		return this.path;
	}
}

