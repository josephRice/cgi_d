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
