module cgi.cgi;
/*****************************************************************************
 * package: cgi
 * module cgi.cgi
 * File: cgi.d
 * Description:  utility d module that contains Classes to build cgi applications.
 * Author: Joseph M. Rice (ricejm01@gmail.com)
 * Date: Wed Dec 18 00:04:03 EST 2014
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

import std.stdio;
import std.string;
import std.conv;
import std.process;
import std.algorithm;
import std.uri;

/**
* this enumeration allows us to describe the type 
* of content the cgi class will be returning and 
* allows us to programatically control the behavior
* of how the what the application is writing to stdout.
* I.E. if content is generally text/html generate the html headers
*	   or if we are a text/plain (possibly a .csv or .txt) file 
*      behave this way.  
*/
enum MIMETYPE {
	TEXT_HTML=0,			
	TEXT_HTML_NO_CACHE,
	TEXT_HTML_RAW,
	TEXT_HTML_NO_CACHE_RAW,
	TEXT_PLAIN,
	TEXT_PLAIN_NO_CACHE,
	RAW_TYPE
}

/**
* Abritrary modes that cgi variable can have
* 
* Normal mode is that the variable is not sticky
* Forward mode is that upon the next form submission or
* 	post/get the cgi varibles should be sent along to be
*	"sticky" to keep state.  
*/
enum CGIMODES {
	NORMAL=0,
	FORWARD=1
}

/**
 * Abritrary modes or states that a cgi variable could be
 * 
 * Normal mode is the varibale is data
 * File mode is to indicate the varible is a file.
 */
enum CGI_VAR_TYPE {
	NORMAL=0,
	FILE=1
}

/**
* CGIFILE class is a data structure that describes the way a 
* file is reprensented from the web server.  (apache)
* 
* Note: currently a glorifed Struct, a class with no methods
* 		as that future plans are to expand this class.
*/
class CGIFILE {
	string filename;
	string content_type;
	string content;

	this() {		
	}
}

/**
* CGIVALS class is a data structure that represents the value
* key pairs that a cgi query string represents.  IE.
* ("?foo=bar&foobar=be") where this query string has two CGIVALs
* contained within. this class allows us to store variables and 
* logically describe what those variables are and assign a mode. 
*/
class CGIVALS {
	string name;
	string value;
	CGIMODES mode;
	CGI_VAR_TYPE type;
	CGIFILE fData;	

	this() {
		name = "";
		value = "";
		mode = CGIMODES.NORMAL;
		type = CGI_VAR_TYPE.NORMAL;
		fData = new CGIFILE();
	}
}

/**
 * see it's a COOKIE class and it's good enough for me.  
 *
 * COOKIE class is a data structure that represents the components 
 * of an html cookie.  
 */
class COOKIE {
	string data;
	string expires;
	string path;
	string domain;

	this() {
		this.data = "";
		this.expires = "";
		this.path = "";
		this.domain = "";
	}

	this(string http_cookie) {
		parseCookieString(http_cookie);
	}

	/**
	 * parse the cookie string and break into key=value pairs
	 *
	 *Note: this function is simplistic and assumes ("data payload"; expires= ; path= ; domain= ;) for the cookie string.
     * so when you use cookies you have to have them in this format.   To do: is make this method smarter. 	 
	 */
	void parseCookieString(string http_cookie) {
		if (http_cookie.length > 0) {
			auto token = findSplit(http_cookie,"; expires=");

			if (token[1] == "; expires=") {
				this.data = chompPrefix(chomp(strip(token[0].idup),"\""),"\"");
				token = findSplit(token[2],"; path=");
			}

			if (token[1] == "; path=") {
				this.expires = strip(token[0].idup);
				token = findSplit(token[2],"; domain=");
			}

			if (token[1] == "; domain=") {
				this.path = strip(token[0].idup);
				this.domain = strip(token[2].idup);
			}
		} else {
			this.data = "";
			this.expires = "";
			this.path = "";
			this.domain = "";
		}
	}

	/**
	 * return a string reprenstation in html of the cookie
	 */
	override string toString() {
		return data~"; expires="~expires~"; path="~path~";";// domain="~domain~";";
	}
}


/**
* CGI class 
*
* Designed to read the environment variables created by web server and 
* will consume the data and make it easily accessible to program with. 
*/
class CGI {
	//
	// Class Varibles
	//
	CGIVALS[] cgiVals;
	string HTTP_USER_AGENT;
	string REQUEST_METHOD;
	string PATH_INFO;
	string CONTENT_TYPE;
	string CONTENT_LENGTH;
	string QUERY_STRING;
	string SCRIPT_NAME;
	string SERVER_NAME;
	string BASE_URL;
	string HTTP_COOKIE;
	string SERVER_PORT;
	string HTTP_HOST;
	string REQUEST_URI;
	private string custom_content_type;
	char[] postData;
	private MIMETYPE mime_type;
	private int mime_type_set;
	private int CGI_ARRAY_START_SIZE=25;
	private string error_msg;
	private COOKIE cookie;

	//
	// Constructor(s)
	//
	this() {
		mime_type_set = 0;
		this.init();
	}

	this(MIMETYPE type) {
		mime_type = type;
		mime_type_set=1;
		this.init();
	}

	~this() {
		this.destroyCgiData();
	}
	//
	// Private Methods
	//
	private void init() {
		int ret = -9;
		//
		//Read environment varibles. 
		//
		REQUEST_METHOD = environment.get("REQUEST_METHOD");
		HTTP_USER_AGENT = environment.get("HTTP_USER_AGENT");
		PATH_INFO = environment.get("PATH_INFO");
		CONTENT_TYPE = environment.get("CONTENT_TYPE");
		CONTENT_LENGTH = environment.get("CONTENT_LENGTH");
		QUERY_STRING = environment.get("QUERY_STRING");
		SCRIPT_NAME = environment.get("SCRIPT_NAME");
		SERVER_NAME = environment.get("SERVER_NAME");
		SERVER_PORT = environment.get("SERVER_PORT");
		HTTP_COOKIE = environment.get("HTTP_COOKIE");
		HTTP_HOST = environment.get("HTTP_HOST");
		REQUEST_URI = environment.get("REQUEST_URI");

		cookie = new COOKIE();

		if (SERVER_PORT == "80") {
			BASE_URL = "http://"~ SERVER_NAME ~ SCRIPT_NAME;
		} else {
			BASE_URL = "https://"~ SERVER_NAME ~ SCRIPT_NAME;
		}

		if (REQUEST_METHOD == "POST" || 
			REQUEST_METHOD == "PUT") {
			if (CONTENT_LENGTH.length == 0) {
				//throw exception. 
			}

			// set our buffer size.  
			postData = new char[to!int(CONTENT_LENGTH)];
			// Read it all at once :)
			stdin.rawRead(postData);

			if (CONTENT_TYPE == "application/x-www-form-urlencoded")
				QUERY_STRING ~= postData.idup;
		} 

		// the foling are just handleded because it assumed that
		// we already grabbed the needed environment variables
		// and we will be leaving it up to the application developer
		// to check method type if they care about it.  
		//REQUEST_METHOD == "DELETE"	
		//REQUEST_METHOD == "GET"

		this.initCGIData();		
	}

	private int initMultipartCGIData(string postData) {
		string boundary;
		string haystack;
		string data;
		string content_disp;
		string content_type;
		string content;
		string filename;
		string name;
		bool isFile = false;
		int i = 0;
		int ret = 1;
		
		//
		// set cgivals array start size
		//
		if (cgiVals.length == 0) {
			cgiVals.length = CGI_ARRAY_START_SIZE;  
		}

		//
		//read bountry string from CONTENT_TYPE;
		//
		//if (CONTENT_TYPE != "multipart/form-data") {
		if (!(startsWith(CONTENT_TYPE,"multipart/form-data;"))) {
			ret = -2; 
			return ret;
		}

		auto boundary_split = findSplit(CONTENT_TYPE, "boundary=");

		if (boundary_split[2].length <= 0) {
			// throw new BoundryNotFoundException;
			ret = -1;
			return ret;
		}

		// for some reason the CONTENT_TYPE boundary does not have the correct 
		// number of '-' So I'm adding 2 so everything lines up. 
		boundary = "--" ~ boundary_split[2].idup;
		//
		// skip the start boundary so we can logically findSplit
		//
		auto token = findSplit(postData,boundary); // skip the first boundry.
		//
		// Parse multipart/form-data
		//
		haystack = token[2].idup;

		//we know to end when our haystack is "--\r\n"
		for (i = 0; haystack.length > 0 && haystack != "--\r\n"; i++) {
			token = findSplit(haystack,boundary);
			//
			// Grow our cgi array if we need too. 
			//
			if (i == cgiVals.length)
				cgiVals.length *= 2;
			//
			// The content-disposition
			//
			data = token[0].idup;
	
			// ok, the boundary also has a "\r\n" at the end, except for the end it has "--\r\n"
			// so our data now begins with "\r\n" so we have to account for this.  
 			auto data_token = findSplit(data, "\r\n");
			data_token = findSplit(data_token[2], "\r\n");

			content_disp = data_token[0].idup;
			//
			// The content-type
			//
			data_token = findSplit(data_token[2], "\r\n");
			content_type = data_token[0].idup;

			//
			// The content
			//
			content = chomp(chompPrefix(data_token[2].idup,"\r\n"),"\r\n");
			//
			//parse content_disposition
			//
			//Content-Disposition: form-data; name="file"; filename="package.json"
			//
			// Find filename
			//
			data_token = findSplit(content_disp,"filename=");
			if (data_token[2].length) {
				// we have a file name and we are a file
				isFile = true;
				filename = chomp(chompPrefix(data_token[2],"\""),"\"");
			}
			//
			// Find name
			//
			data_token = findSplit(content_disp,"name=");
			if (isFile) {
				data_token = findSplit(data_token[2],";");
				name = chomp(chompPrefix(data_token[0],"\""),"\"");
			} else {
				name = chomp(chompPrefix(data_token[2],"\""),"\"");
			}

			//
			// Store the parsed data
			//
			cgiVals[i] = new CGIVALS;

			cgiVals[i].name = name.idup; //name 
			if(!isFile) {
				cgiVals[i].value = content.idup; //value
			} else {
				cgiVals[i].value = "";
				cgiVals[i].type = CGI_VAR_TYPE.FILE;
				cgiVals[i].fData.filename = filename.idup;
				cgiVals[i].fData.content_type = content_type.idup;
				cgiVals[i].fData.content = content.idup;
			}
			//
			// Make the Haystack smaller
			//
			haystack = token[2].idup;
		}

		cgiVals.length = i;
		ret = i;

		return ret;
	}

	//look at QUERY_STRING and parse our cgivals. 
	private void initCGIData() {
		string haystack = QUERY_STRING.idup;
		int i = 0, ret = 0;

		if (postData.length > 0 &&  //  CONTENT_TYPE = multipart/form-data; boundary=------------------------cdcd8bbbb646b6ae
			(startsWith(CONTENT_TYPE,"multipart/form-data;"))) {
		    //CONTENT_TYPE == "multipart/form-data") {
			ret = initMultipartCGIData(to!string(postData));
		}

		if (ret >= 0) {
			if (cgiVals.length == 0) {
				cgiVals.length = CGI_ARRAY_START_SIZE;  
			} else {
				cgiVals.length *= 2;	
			}	

			for (i = ret; haystack.length > 0 ; i++) {
				auto pair = findSplit(haystack,"&");
				auto vals = findSplit(pair[0],"=");	
				if (i == cgiVals.length)
					cgiVals.length *= 2;
				cgiVals[i] = new CGIVALS;
				cgiVals[i].name = vals[0].idup; //name 
				cgiVals[i].value= urlDecode(vals[2]).idup; //value
				haystack = pair[2].idup;
			}
			cgiVals.length = i;
		}
	}


	private void destroyCgiData() {
		int i = 0; 
		for (i = 0; i != cgiVals.length; ++i) {
			destroy(cgiVals[i]);
		}
	}

	private string urlDecode(string url) {
		return decodeComponent(url);
	}

	private string urlEncode(string url) {
		return encodeComponent(url);
	}

	//
	// Class Methods
	//

	/**
	* Check if a cgi variable exists with the passed in name.
	*
	* returns true if the variable exists.
	*/
	bool exists(string name) {
		bool ret = false;
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				ret = true;
				break;
			}
		}
		return ret;
	}

	/**
	* Check if a cgi variable exists with the passed in name and index.
	* keep in mind that the cgi environment can have multiple variables 
	* with the same name the passed in index allows us to specify which 
	* one to check for.
	*
	* returns true if the variable exists.
	*/
	bool exists(string name, int index) {
		bool ret = false;
		int i = 0, count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				if (count == index) {
					ret = true;
					break;
				}
				count++;
			}
		}
		return ret;
	}

	/**
	* Get the value for the cgi variable for the passed in name
	*
	* return a string with the cgi variables value.
	*/
	string getVal(string name) {
		string ret = "";
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				ret = (cgiVals[i].value).idup;
				break;
			}
		}

		return ret;
	}

	/**
	* Get the value for the cgi variable for the passed in name and index.
	* keep in mind that the cgi environment can have multiple variables
	* of the same name the index allows us to specify which one we want.
	*
	* return a string with the cgi variables value.
	*/
	string getVal(string name, int index) {
		string ret = "";
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				if (count == index) {
					ret = (cgiVals[i].value).idup;
					break;
				} 
				count++;
			}
		}
		return ret;
	}
	
	/**
	* Since the cgi environment can have multiple variables we might 
	* want to get all the values.  
	*
	* return a string array of all the values for a varible name
	*/
	string[] getVal_m(string name) {
		string[] ret;
		int i = 0;
		int count = 0;

		if (ret.length == 0) {
			ret.length = CGI_ARRAY_START_SIZE;
		} 

		for (i = 0; i != cgiVals.length; ++i) {

			if (count == ret.length) {
				ret.length *= 2;
			}

			if (cgiVals[i] && cgiVals[i].name == name) {
				ret[count] = (cgiVals[i].value).idup;				
				count++;
			}
		}
		ret.length = count;
		return ret;
	}

	/**
  	* Instead of reading the cgi data only from the environment, 
	* we can set our own cgi variables from memory.
	*/	
	void setVal(string name, string value, CGIMODES mode, 
				CGI_VAR_TYPE type, CGIFILE fData) {
		ulong i = cgiVals.length;

		cgiVals.length += 1;

		cgiVals[i] = new CGIVALS;
		cgiVals[i].name = name;
		cgiVals[i].value = value;
		cgiVals[i].mode = mode;
		cgiVals[i].type = type;
		if (fData) {
			cgiVals[i].fData.filename = fData.filename;
			cgiVals[i].fData.content_type = fData.content_type;
			cgiVals[i].fData.content = fData.content;
		}

	}
	/**
	* set the cgi Variable mode of a given name
	*/
	void setVarMode(string name, CGIMODES mode) {
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				cgiVals[i].mode = mode;
				break;
			}
		}
	}

	/**
	* set the cgi Variable mode of a given name and index
	* Keep in mind the cgi environment can contain multiple 
	* variables with the same name. The index allows us to 
	* get the one we want.
	*/
	void setVarMode(string name, CGIMODES mode, int index) {
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				if (count == index) {
					cgiVals[i].mode = mode;
					break;
				}
			   count++;	
			}
		}
	}

	/**
	* Get the cgi Variable mode of a given name.  
	*
	* returns the CGIMODES enum value for the variable with the name passed.  
	*/
	CGIMODES getVarMode(string name) {
		int i = 0;
		CGIMODES ret;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				ret = cgiVals[i].mode;
			}
		}
		return ret;
	}

	/**
	* Get the cgi Variable mode of a given name and index
	* Keep in mind the cgi environment can contain multiple 
	* variables with the same name. The index allows us to 
	* get the one we want.
	*
	* returns the CGIMODES enum value for the variable with the name passed.  
	*/
	CGIMODES getVarMode(string name, int index) {
		int i = 0;
		int count = 0;
		CGIMODES ret;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && cgiVals[i].name == name) {
				if (count == index) {
					ret = cgiVals[i].mode;
					break;
				} 
				count++;
			}
		}
		return ret;
	}

	/**
	* create a string of the cgi variables that are in forward mode.
    * This allows us to use cgi variables to keep state and forward 
	* them on to another form submission.  This allows the programmer 
    * to selectivly forward and unforward cgi variables for flow/state 
	* control.
	*
	* returns a string containing query string of the variables in forward mode.	
	*/
	string getForwardVarString() {
		string ret = "";
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i].mode == CGIMODES.FORWARD) {
				ret ~=  cgiVals[i].name ~ "=" ~ urlEncode(cgiVals[i].value);
				if ((i + 1) != cgiVals.length) {
					ret ~= "&";
				}
			}
		}

		return ret;
	}

	/**
	* Check to see if a cgi variable with name is a file or not.
	*
	* returns true if the cgi variable is file.
	*/
	bool varIsFile(string name) {
		bool ret = false;
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] &&
				cgiVals[i].name == name &&
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				ret = true;
				break;
			}
		}

		return ret;
	}

	/**
	* Check to see if a cgi variable with name and index is a file or not.
	* keep in mind that the cgi environments may contain several variables 
	* with same name.  the index allows us to specify which one.
	*
	* returns true if the cgi variable is file.
	*/
	bool varIsFile(string name,int index) {
		bool ret = false;
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] &&
				cgiVals[i].name == name &&
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					ret = true;
					break;
				}
				count++;
			}
		}

		return ret;
	}

	/**
	* Get the file content type of the the file posted/put in the cgi envirnment 
	* with the variable string name.  
	*
	* returns a string containing the original content type of the file uploaded. 
	*/
	string getFileContentType(string name) {
		string ret = "";
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				ret = cgiVals[i].fData.content_type.idup;
				break;
			}
		}

		return ret;
	}

	/**
	* Get the file content type of the the file posted/put in the cgi envirnment 
	* with the variable string name with the index.  
	* Keep in mind that a variable can exist multiple times in the cgi environment 
	* and the index allows us to specify exactly which one.
	*
	* returns a string containing the original content type of the file uploaded. 
	*/
	string getFileContentType(string name, int index) {
		string ret = "";
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					ret = cgiVals[i].fData.content_type.idup;
					break;
				}
				count++;
			}
		}

		return ret;
	}

	/**
	* Get the file name of the the file posted/put in the cgi envirnment 
	* with the variable string name. 
	*
	* returns a string containing the original name of the file uploaded. 
	*/
	string getFileName(string name) {
		string ret = "";
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				ret = cgiVals[i].fData.filename.idup;
				break;
			}
		}

		return ret;
	}

	/**
	* Get the file name of the the file posted/put in the cgi envirnment 
	* with the variable string name with the index.  
	* Keep in mind that a variable can exist multiple times in the cgi environment 
	* and the index allows us to specify exactly which one.
	*
	* returns a string containing the original name of the file uploaded. 
	*/
	string getFileName(string name, int index) {
		string ret = "";
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					ret = cgiVals[i].fData.filename.idup;
					break;
				}
				count++;
			}
		}

		return ret;
	}

	/**
	* Get the content of a file in the cgi environment with string name.
	*
	* returns a string of the file's content.
	*/
	string getFileContent(string name) {
		string ret = "";
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				ret = cgiVals[i].fData.content.idup;
				break;
			}
		}

		return ret;
	}

	/**
	* Get the content of a file in the cgi environment with string name and the index.
	* keep in mind that we can have the same cgi variable with string name several times
	* index allows us to specify which one we want. 
	*
	* returns a string of the file's content.
	*/
	string getFileContent(string name, int index) {
		string ret = "";
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					ret = cgiVals[i].fData.content.idup;
					break;
				}
				count++;
			}
		}

		return ret;
	}

	/**
	* Get a file from the cgi enviroment of string name
  	* returns a CGIFILE class.	
	*/
	CGIFILE getFile(string name) {
		CGIFILE ret;
		int i = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				ret = cgiVals[i].fData;
				break;
			}
		}

		return ret;
	}


	/**
	*
	*/
	CGIFILE getFile(string name, int index) {
		CGIFILE ret;
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] && 
				cgiVals[i].name == name && 
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					ret = cgiVals[i].fData;
					break;
				}
				count++;
			}
		}

		return ret;
	}

	/**
	* Dumps the system environment variables to the page.
	*/
	void dumpEnv() {
		auto env = environment.toAA();
		auto keys = env.keys;
		auto values = env.values;
		 
    	for (int i = 0; i != values.length; ++i) {
        	writefln("%s = %s<br>",keys[i],values[i]);
    	}

	}

	/**
	* Dumps the contents of the CGI class to the page. Very useful for debuging
	*/
	void dump() {
		int i = 0;
		writeln("+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=<br>");
		writeln("+ Environment                                              =<br>");
		writeln("+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=<br>");
		writefln("REQUEST_METHOD = %s<br>",this.REQUEST_METHOD);
		writefln("HTTP_USER_AGENT = %s<br>",this.HTTP_USER_AGENT);
		writefln("PATH_INFO = %s<br>",this.PATH_INFO);
		writefln("CONTENT_TYPE = %s<br>",this.CONTENT_TYPE);
		writefln("CONTENT_LENGTH = %s<br>",this.CONTENT_LENGTH);
		writefln("QUERY_STRING = %s<br>",this.QUERY_STRING);
		writefln("HTTP_COOKIE = %s<br>",this.HTTP_COOKIE);
		writefln("BASE_URL = %s<br>",this.BASE_URL);
		writefln("SCRIPT_NAME = %s<br>",this.SCRIPT_NAME);
		writeln("+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=<br>");
		writeln("+ CGI vals                                                 =<br>");
		writeln("+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=<br>");
		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i]) {
				if (cgiVals[i].type == CGI_VAR_TYPE.FILE) {
					writefln("Name = (%s) | filename = (%s) |"
							" content-type (%s)| forward = (%d) <br>",
							cgiVals[i].name,cgiVals[i].fData.filename,
							cgiVals[i].fData.content_type,cgiVals[i].mode);
				} else {
					writefln("Name = (%s) | value = (%s) | forward = (%d)<br>",
						cgiVals[i].name,cgiVals[i].value,cgiVals[i].mode);
				}
			}	
		}
		writeln("+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=<br>");

	}

	/**
	* Print to standard out http headers initialize the page.
	* 
	* handles the standard http header of content type a carriage 
	* return followed by two new lines, etc... for you. so that the
	* web server can return correct data back to the calling browser.
	* 
	* depending on the MIMETYPE value we have different behaviors
	*
	* Type TEXT_HTML, will write out the http header, cookies, and start 
	*  the html for you if you want to be lazy and just concentrate whats 
	*  the <body> tag only.  
	* 
	* Type TEXT_HTML_NO_CACHE is basically the same behavior as TEXT_HTML,
	*  but it sets the browsers cache behavior to not cache the page.
	* 
	* Types TEXT_HTML_RAW and TEXT_HTML_NO_CACHE_RAW write out the HTTP header
	*  information and cookie information only.  It does not start the HTML for you!
	*  you will have to write to standard out valid html.
	*
    * type RAW_TYPE is for when you have a content type that is not text/html or 
    *  text/plain.  for example you want to write to standard out JSON or XML data.
    *  you will have to set valid mime type for what you are sending back to the browser. 
	*
	* types TEXT_PLAIN and TEXT_PLAIN_NO_CACHE is a lazy short cut if you just want to return
	*  to the browser anything that has the mime content-type of text/plain.   
	*/
	void pageStart() {
		if (mime_type_set) {
			this.pageStart(mime_type);
		} else {
			this.pageStart(MIMETYPE.TEXT_PLAIN);
		}
	}

	void pageStart(MIMETYPE type) {
		string content_type = "";
		
		switch (type) {
			case MIMETYPE.TEXT_HTML:			
			case MIMETYPE.TEXT_HTML_NO_CACHE:
			case MIMETYPE.TEXT_HTML_RAW:
			case MIMETYPE.TEXT_HTML_NO_CACHE_RAW:
				content_type = "text/html";
				break;
			case MIMETYPE.RAW_TYPE:
				content_type = custom_content_type;
				break;
			case MIMETYPE.TEXT_PLAIN:
			case MIMETYPE.TEXT_PLAIN_NO_CACHE:
			//Fall through to default
			default:
				content_type="text/plain";
				break;
		}


		if( type == MIMETYPE.TEXT_HTML_NO_CACHE ||
			type == MIMETYPE.TEXT_PLAIN_NO_CACHE ||
			type == MIMETYPE.TEXT_HTML_NO_CACHE_RAW) {
			write("Expires: 0\r\n");
			write("Cache-Control: no-store\r\n");
		}


		if (content_type == "text/html") {					
			if (cookie.data.length != 0) {
				writef("Set-Cookie: %s\r\n",cookie.toString());
			}
		}

		if (content_type.length != 0 ) {
			writef("Content-type: %s\r\n",content_type);
			write("\n");
			if (type == MIMETYPE.TEXT_HTML_NO_CACHE || type == MIMETYPE.TEXT_HTML) {
				write("<html>");
				write("<head>");
				if (type == MIMETYPE.TEXT_HTML_NO_CACHE) {
					write("<meta http-equiv=\"CACHE-CONTROL\" "
							"content=\"NO-CACHE\">\r\n");
				}
			}
		} 
	}

	/**
	 * stream the contents of a file back to the browser.  you 
	 * will have to store the file in the cgi class instance by 
	 * setting a CGIVAL with CGIFILE class.  
	 */
	void streamFile(string name) {
		this.streamFile(name,0);
	}

	void streamFile(string name, int index) {
		int i = 0;
		int count = 0;

		for (i = 0; i != cgiVals.length; ++i) {
			if (cgiVals[i] &&
				cgiVals[i].name == name &&
				cgiVals[i].type == CGI_VAR_TYPE.FILE) {
				if (count == index) {
					writef("Content-type: %s\r\n\n",cgiVals[i].fData.content_type);
					writef("%s",cgiVals[i].fData.content);
					break;
				}
				count++;
			}
		}
	}

	/**
	* end the page being returned
	*
	* if you used one of the shortcut MIMETYPE's TEXT_HTML 
	* and TEXT_HTML_NO_CACHE this will close the <html> tag 
	* created for you. 
	*/
	void pageEnd() {
		if (mime_type_set) {
			this.pageEnd(mime_type);
		} else {
			this.pageEnd(MIMETYPE.TEXT_HTML);
		}
	}
	
	/**
	*
	*/
	void pageEnd(MIMETYPE type) {
		switch (type) {
			case MIMETYPE.TEXT_HTML:
			case MIMETYPE.TEXT_HTML_NO_CACHE:
				write("</html>\n");
				break;
			default:
				break;
		}
	}

	/**
	 * set the MIMETYPE.
	 */  
	void setMimeType(MIMETYPE type) {
		mime_type = type;
		mime_type_set=1;
	}

	void setMimeType(string custom_content_type) {
		mime_type=MIMETYPE.RAW_TYPE;
		mime_type_set=1;
		this.custom_content_type = custom_content_type;
	}

	/**
	 * get the current MIMETYPE
	 */
	MIMETYPE getMimeType() {
		return mime_type;
	}

	/**
	 * set the class instance mime type to common mimetypes 
	 * based on a file extension.
	 *
	 * Note: Does not include every possible mime type, and 
	 * 	will be added to in future releases. It could also 
	 *  be smarter by doing a look up, but I'm trying to be 
	 *  light weight and not require a support file, or 
	 *  having to make a external connection to get data. if
	 *  you need that kind of functionality, then it's up to 
	 *  the application developer to make that design call.
	 *  
	 */
	void discoverMimeType(string extension) {
		// figure out our content type based off the extension. 
		switch (extension) {
			case "widget":
			case "WIDGET":
			case "html":
			case "HTML":
				this.setMimeType(MIMETYPE.TEXT_HTML_RAW);
				break;
			case "txt":
			case "TEXT":
			case "text/plain":
				this.setMimeType(MIMETYPE.TEXT_PLAIN);
				break;
			case "xml":
			case "XML":
				this.setMimeType("application/xml");
				break;
			case "js":
			case "JS":
				this.setMimeType("application/javascript");
				break;
			case "css":
			case "CSS":
				this.setMimeType("text/css");
				break;
			case "png":
			case "PNG":
				this.setMimeType("image/png");
				break;
			case "jpg":
			case "JPG":
			case "jpeg":
			case "JPEG":
				this.setMimeType("image/png");
				break;
			case "svg":
			case "SVG":
				this.setMimeType("image/svg+xml");
				break;
			case "gif":
			case "GIF":
				this.setMimeType("image/gif");
				break;
			case "tif":
			case "TIF":
			case "tiff":
			case "TIFF":
				this.setMimeType("image/tiff");
				break;
			default:
				this.setMimeType(MIMETYPE.TEXT_PLAIN);
				break;
		}
	}

	/**
	* set the cookie.
	*/
	void setCookie(COOKIE cookie) {
		this.cookie = cookie;
	}

	/**
	* Get the cookie.
	*/
	COOKIE getCookie() {
		return this.cookie;
	}
	
	/**
	* lazy javascript that you can use to tell the browser 
	* to keep scrolling down as you write content. This is 
	* handy if you said don't cache, and your web server 
	* is set up to not compress the returned data to browser.
	*
	* for example you want to write a UI that you upload a .csv
	* file to, and you have to do things with the data, and you 
	* have implemented a loging system that writes to a file and
	* stdout at the same time,  you could display your logs real
	* time back to a browser as you process the .csv file.  
	*
	* it's just been useful.  use it or don't.
	*/
	void autoScrollInit() {
		write("<script type=\"text/javascript\">\n");
		write("function AutoScroll()\n");
		write("{\n");
		write("   var cw = document.body.clientHeight;\n");
		write("   var fh = document.body.scrollHeight;\n");
		write("   if (fh > cw) {\n");
		write("      document.body.scrollTop = fh;\n");
		write("   }\n");
		write("}\n");
		write("</script>\n");
	}

	/**
	* tell the browser to run the AutoScroll javascript. 
	*/
	void runAutoScroll() {
		write("<script type=\"text/javascript\">\n");
		write("AutoScroll();");
		write("</script>\n");
	}

	/**
	* getter method for error_msg.   
	*/
	string getErrorMsg() {
		return error_msg;
	}
}
