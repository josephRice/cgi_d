# cgi_d

### Utilities for building [CGI] applications in D

####Why [CGI]?

Well because **New** does not always mean **improved**.  [CGI] programming has been around about as html. It is a very simple and elegante way work with a web server to add dynamic content.  [CGI] applications by nature are RESTful state applications. Just like a web server streams out static .html files, you can have the web server execute your program.  [CGI] programming is not like other programming where you might have a run time loop to keep the program active until directed to close. [CGI] programs do there work and exit.  

Do not confuse [CGI] with fCGI (*Fast [CGI]*). Fast [CGI] programming techniques work differently than [CGI].  There is actually a run time loop in play with Fast [CGI] that keeps the program running to respond to incomming requests handed off to the program by the web server.  If you want Fast [CGI] there are other libraries for that implementation.  

Wait, what did I just Read???  Why would I want to use [CGI] over other web development backend libries then?  Glad you asked, Compared to other web development libraries that add overhead by implementing a full http web server stack inside your program. Let's let web server applications like Apache or Ngnix do what they do best. This means that you program does not control the port it is running on or how many connections it allows, etc... The draw back is that everything is 100% synchronous. However, if you don't need asynchronous comunication (web sockets,etc...) then why add the overhead. let's allow yourselve to concentrate on doing exactly what your program needs to do and exit.  So it may be a shift in thinking if you don't understand [CGI]. Your program get's ran when it needs to be and nothing more than that. You have to write your programs to take a set of inputs and process them, and return a response to those inputs.       

Note: There are fast [CGI] libraries that work with Apache and Nginx too.  Because we know; **You wouldn't use a sledge hammer when you really need a screw driver.** So D seemed to missing a [CGI] library, now you can evaluate your needs for your project and have a full toolbox.  Use the sledge hammer when it's called for, use the screw driver when it called for. Right tools for the right job. 

####What would I use [CGI] for?
* RESTful web services (http to it's full potential) 
* light weight web app development in D
* streaming services
* pretty much all types of web development

####How does [CGI] work? 
In a nutshell; Environment variables are set by the web server allowing you some inputs on what to do.  Any content uploaded by the client web browser to the web sever is available to be read in by your program on stdin, and your programs writes output to stdout which the web server then returns back to the client web browser.

If you want to know more I suggest reading ["Sam's Teach Yourself CGI Programming in A WEEK" ISBN: 0-57521-381-8](https://www.amazon.com/Teach-Yourself-Programming-Colburn-Paperback/dp/B011YTOURO/ref=sr_1_3?s=books&ie=UTF8&qid=1477021076&sr=1-3&keywords=sam%27s+teach+yourself+CGI+Programming+in+a+week "Amazon.com"). It's an oldie but a goodie, if your into dead tree books. Otherwise check out the [https://en.wikipedia.org/wiki/Common_Gateway_Interface](https://en.wikipedia.org/wiki/Common_Gateway_Interface "wikipedia") and consult [the body of all human knowledge](https://www.google.com/#q=CGI+programming)


### cgi_d usage examples
  
```D
import cgi.cgi;
import cgi.router;
import std.stdio;
import std.algorithm;
import std.file;
import std.conv;

//
// curl examples for posting a file since there is no form displayed replace <..> with approprate values
//
// curl -F test=123 -F test=another_test -F test="this is a Third Test" -F bob=1 -F file=@./<some file you have> -F file=@./<some other file you have> "http://localhost/cgi_d/cgi_d_test.cgi"
// curl -F test=123 -F test=another_test -F test="this is a Third Test" -F bob=1 -F file=@./<some file you have> -F file=@./<some other file you have> "http://localhost/cgi_d/cgi_d_test.cgi/repeat/a/file"
//
// other wise point your browser to http://localhost/cgi_d/cgi_d_test.cgi and play with the paths
//  * http://localhost/cgi_d/cgi_d_test.cgi/stream/
//  * http://localhost/cgi_d/cgi_d_test.cgi?test=123&test=another_test&test=this+is+a+Third+Test&bob=1


class REPEAT : ROUTE // Q:why are my class names all caps?  A:Well the old-school C programmer in me likes 
{                    // all #typedefs to be UPPERCASE for readablity, and VI/VIM coloring won't recongnize 
	CGI cgi;         // it as a new data type.  Since class definition is litterally defining a new type
	string name;     // I continue with this naming convention tradition of making new types UPPERCASE. :)  

	this(string name) {
		this.name = name;
	}

	this(string name, CGI cgi) {
		this.name = name;
		this.cgi = cgi;
	}

	void run(CGI cgi) {
		this.cgi = cgi;
		cgi.streamFile(name);
	}
}

class STREAM : ROUTE 
{
	CGI cgi;
	string filename;

	this(string filename) {
		this.filename = filename;
	}

	this(string filename, CGI cgi) {
		this.filename = filename;
		this.cgi = cgi;	
	}

	void run(CGI cgi) {
		this.cgi = cgi;

		char[] content;
		// This program reads a file and prints it to the screen
		try {
			CGIFILE fData = new CGIFILE;
			
			content = cast(char[])read(filename);
			
			fData.filename = "cgi.html";
			fData.content_type = "Content-Type: text/html";
			fData.content = to!string(content).idup;
			
			cgi.setVal("file","",CGIMODES.NORMAL,CGI_VAR_TYPE.FILE,fData);
			cgi.streamFile("file");
		} catch (FileException fe) {
			cgi.pageStart();
			writefln("A file exception occured: %s<br>",fe.toString());
			cgi.pageEnd();
		} catch (Exception e) {
			cgi.pageStart();		    
			writefln("An exception occured: %s<br>",e.toString());
			cgi.pageEnd();
		}
	}
}


int main() 
{    
	bool routerRan = false;
    //MIMETYPE type = MIMETYPE.TEXT_PLAIN_NO_CACHE;
    MIMETYPE type = MIMETYPE.TEXT_HTML_NO_CACHE;

    //CGI cgi = new CGI();
	//CGI cgi = new CGI(MIMETYPE.TEXT_HTML_NO_CACHE);	
	CGI cgi = new CGI(type);

	ROUTER router = new ROUTER(cgi);

	try {
		//test router runRoute with a path with multiples
		routerRan = router.runRoute("/repeat/a/file",new REPEAT("file"));
		//test router runRoute with a single path
		routerRan = router.runRoute("/stream",new STREAM("./cgi.html"));
			
		if (!routerRan) {
			cgi.pageStart();

			writefln("<h1>Hello cgi_d!</h1>");

			if (startsWith(cgi.PATH_INFO,"/stream")) {
				writefln("path_info starts with /stream<br>");
			} else {
				writefln("path_info does not start with /stream<br>");
			}

			cgi.dumpEnv();

			//
			// test exists and getVal
			//
			if (cgi.exists("test")) {
				writefln("cgi var named \"test\" exists with value (%s)<br>",cgi.getVal("test"));
			} else {
				writeln("cgi var named \"test\" does not exist<br>");
			}
			
			//
			// test exists overload for multi values.
			//
			if (cgi.exists("test",1)) {
				writefln("cgi var named \"test\" exists with value (%s)<br>",cgi.getVal("test",1));
			} else {
				writeln("cgi var named \"test\" does not exist<br>");
			}

			//
			// test getVal_m
			//
			string[] val_array = cgi.getVal_m("test");

			writefln("val_array.length = %d<br>",val_array.length);

			for (int i = 0; i != val_array.length; ++i) {
				if (val_array[i]) writefln("test[%d] = (%s)<br>",i,val_array[i]);
			}

			//
			// test setVarMode
			//
			cgi.setVarMode("bob",CGIMODES.FORWARD);
			cgi.setVarMode("test",CGIMODES.FORWARD,2);
			//
			// test getVarMode
			//
			CGIMODES mode;

			mode = cgi.getVarMode("bob");

			if (mode == CGIMODES.FORWARD) {
				writeln("bob is set to forward<br>");
			} else {
				writeln("bob is set to Normal<br>");
			}

			mode = cgi.getVarMode("test",2);

			if (mode == CGIMODES.FORWARD) {
				writeln("third test is set to forward<br>");
			} else {
				writeln("third test is set to Normal<br>");
			}

			//
			// test getForwardVarString
			//
			writefln("the forward vars (%s)<br>",cgi.getForwardVarString());

			//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
			// test file methods
			//=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

			//
			// varIsFile 
			//
			if (cgi.varIsFile("file")) {
				CGIFILE fData;

				writeln("var file is a file.<br>");

				//
				// getFileName
				//
				writefln("var file filename (%s)<br>",cgi.getFileName("file"));

				//
				// getFileContentType 
				//
				writefln("var file content type (%s)<br>",cgi.getFileContentType("file"));

				//
				// getFileContent 
				//
				writefln("var file content (%s)<br>",cgi.getFileContent("file"));

				//
				//	CGIFILE getFile
				//
				fData = cgi.getFile("file");
				if (fData) {
					writefln("fData.filename = (%s)<br>",fData.filename);
					writefln("fData.content_type = (%s)<br>",fData.content_type);
					writefln("fData.content = (%s)<br>",fData.content);
				}
			} else {
				writeln("var file is not a file.<br>");
			}

			if (cgi.varIsFile("file",1)) {
				CGIFILE fData;

				writeln("var file is a file.<br>");

				//
				// getFileName
				//
				writefln("var file filename (%s)<br>",cgi.getFileName("file",1));

				//
				// getFileContentType 
				//
				writefln("var file content type (%s)<br>",cgi.getFileContentType("file",1));

				//
				// getFileContent 
				//
				writefln("var file content (%s)<br>",cgi.getFileContent("file",1));

				//
				//	CGIFILE getFile
				//
				fData = cgi.getFile("file",1);
				if (fData) {
					writefln("fData.filename = (%s)<br>",fData.filename);
					writefln("fData.content_type = (%s)<br>",fData.content_type);
					writefln("fData.content = (%s)<br>",fData.content);
				}
			} else {
				writeln("var file is not a file.<br>");
			}

			cgi.dump(); 

			cgi.pageEnd();
		}
	} catch (Exception e) {
		cgi.pageStart();		    
		writefln("An exception occured: %s<br>",e.toString());
		cgi.pageEnd();
	}

	destroy(cgi);

    return 0;
}
```

*[CGI]: Common Gateway Interface