import "dart:io";
import "dart:uri";
import "dart:json";
import "package:args/args.dart";

String fileDate(Date date) => "${date.year}${(date.month < 10) ? 0 : ""}${date.month}${(date.day < 10) ? 0 : ""}${date.day}_${(date.hour < 10) ? 0 : ""}${date.hour}${(date.minute < 10) ? 0 : ""}${date.minute}${(date.second < 10) ? 0 : ""}${date.second}";
String capitalize(String string) => "${string.substring(0,1).toUpperCase()}${string.substring(1)}";
String cleanName(String name) => name.replaceAll(new RegExp(r"(\W)"), "_");

const Map parameterType = const {
  "string": "String",
  "number": "num",
  "integer": "int",
  "boolean": "bool"
};  

class Generator {
  String _data;
  Map _json;
  String _name;
  String _version;
  String _libraryName;

  Generator(this._data) {
    _json = JSON.parse(_data);
    _name = _json["name"];
    _version = _json["version"];
    _libraryName = cleanName("${_name}_${_version}_api_client");
  }

  void generateClient(String outputDirectory) {
    var folderName = "$outputDirectory/$_libraryName";
    (new Directory("$folderName/lib/src")).createSync(recursive: true);

    (new File("$folderName/pubspec.yaml")).writeAsStringSync(_createPubspec());

    (new File("$folderName/lib/$_name.dart")).writeAsStringSync(_createLibrary());
    
    (new File("$folderName/lib/src/client.dart")).writeAsStringSync(_createClientClass());

    (new File("$folderName/lib/src/schemas.dart")).writeAsStringSync(_createSchemas());

    (new File("$folderName/lib/src/resources.dart")).writeAsStringSync(_createResources());

    (new File("$folderName/lib/src/$_name.dart")).writeAsStringSync(_createMainClass());
  }

  String _createPubspec() {
    return """
name: $_libraryName
version: 0.0.1
description: Auto-generated client library for accessing the $_name $_version API
author: Gerwin Sturm (scarygami/+)

dependencies:
  dart_google_oauth2_library:
    git: git://github.com/Scarygami/dart-google-oauth2-library.git
""";
  }

  String _createLibrary() {
    return """
library $_name;

import "dart:html";
import "dart:uri";
import "dart:json";
import "package:dart_google_oauth2_library/oauth2.dart";

part "src/client.dart";
part "src/$_name.dart";
part "src/schemas.dart";
part "src/resources.dart";
""";
  }

  String _createSchemas() {
    var tmp = new StringBuffer();
 
    tmp.add("part of $_name;\n\n");

    if (_json.containsKey("schemas")) {
      _json["schemas"].forEach((key, schema) {
        tmp.add(_createSchemaClass(key, schema));
      });
    }    
    
    return tmp.toString();
  }

  String _createResources() {
    var tmp = new StringBuffer();
    
    tmp.add("part of $_name;\n\n");
    
    if (_json.containsKey("resources")) {
      _json["resources"].forEach((key, resource) {
        tmp.add(_createResourceClass(key, resource));
      });
    }
    
    return tmp.toString();
  }
  
  String _createMainClass() {
    var tmp = new StringBuffer();
    tmp.add("part of $_name;\n\n");
    tmp.add("/** Client to access the $_name $_version API */\n");
    if (_json.containsKey("description")) {
      tmp.add("/** ${_json["description"]} */\n");
    }
    tmp.add("class ${capitalize(_name)} extends Client {\n");
    if (_json.containsKey("resources")) {
      tmp.add("\n");
      _json["resources"].forEach((key, resource) {
        var subClassName = "${capitalize(key)}Resource";
        tmp.add("  $subClassName _$key;\n");
        tmp.add("  $subClassName get $key => _$key;\n");
      });
    }
    if (_json.containsKey("parameters")) {
      _json["parameters"].forEach((key, param) {
        var type = parameterType[param["type"]];
        if (type != null) {
          tmp.add("\n");
          tmp.add("  /**\n");
          if (param.containsKey("description")) {
            tmp.add("   * ${param["description"]}\n");
          }
          tmp.add("   * Added as queryParameter for each request.\n");
          tmp.add("   */\n");
          tmp.add("  $type get $key => _params[\"$key\"];\n");
          tmp.add("  set $key($type value) => _params[\"$key\"] = value;\n");
        }
      });
    }
    tmp.add("\n  ${capitalize(_name)}([OAuth2 auth]) : super(auth) {\n");
    tmp.add("    _baseUrl = \"${_json["baseUrl"]}\";\n");
    tmp.add("    _rootUrl = \"${_json["rootUrl"]}\";\n");
    if (_json.containsKey("resources")) {
      _json["resources"].forEach((key, resource) {
        var subClassName = "${capitalize(key)}Resource";
        tmp.add("    _$key = new $subClassName._internal(this);\n");
      });
    }
    tmp.add("  }\n");
    
    if (_json.containsKey("methods")) {
      _json["methods"].forEach((key, method) {
        tmp.add("\n");
        tmp.add(_createMethod(key, method));
      });
    }
    
    tmp.add("}\n");

    return tmp.toString();
  }

  String _createSchemaClass(String name, Map data) {
    var tmp = new StringBuffer();
    Map subSchemas = new Map();

    if (data.containsKey("description")) {
      tmp.add("/** ${data["description"]} */\n");
    }

    tmp.add("class ${capitalize(name)} {\n");

    if (data.containsKey("properties")) {
      data["properties"].forEach((key, property) {
        var schemaType = property["type"];
        bool array = false;
        var type;
        if (schemaType == "array") {
          array = true;
          schemaType = property["items"]["type"];
        }
        switch(schemaType) {
          case "object":
            var subSchemaName = "${capitalize(name)}${capitalize(key)}";
            type = subSchemaName;
            if (array) {
              subSchemas[subSchemaName] = property["items"];
            } else {
              subSchemas[subSchemaName] = property;
            }
            break;
          case "string": type = "String"; break;
          case "number": type = "num"; break;
          case "integer": type = "int"; break;
          case "boolean": type = "bool"; break;
        }
        if (type == null) {
          if (array) {
            type = property["items"]["\$ref"];
          } else {
            type = property["\$ref"];
          }
        }
        if (type != null) {
          if (property.containsKey("description")) {
            tmp.add("\n  /** ${property["description"]} */\n");
          }
          if (array) {
            tmp.add("  List<$type> $key;\n");
          } else {
            tmp.add("  $type $key;\n");
          }
        }
      });
    }

    tmp.add("\n");
    tmp.add("  /** Create new $name from JSON data */\n");
    tmp.add("  ${capitalize(name)}.fromJson(Map json) {\n");
    if (data.containsKey("properties")) {
      data["properties"].forEach((key, property) {
        var schemaType = property["type"];
        bool array = false;
        bool object = false;
        var type;
        if (schemaType == "array") {
          array = true;
          schemaType = property["items"]["type"];
        }
        switch(schemaType) {
          case "object":
            type = "${capitalize(name)}${capitalize(key)}";
            object = true;
            break;
          case "string": type = "String"; break;
          case "number": type = "num"; break;
          case "integer": type = "int"; break;
          case "boolean": type = "bool"; break;
        }
        if (type == null) {
          object = true;
          if (array) {
            type = property["items"]["\$ref"];
          } else {
            type = property["\$ref"];
          }
        }
        if (type != null) {
          tmp.add("    if (json.containsKey(\"$key\")) {\n");
          if (array) {
            tmp.add("      $key = [];\n");
            tmp.add("      json[\"$key\"].forEach((item) {\n");
            if (object) {
              tmp.add("        $key.add(new $type.fromJson(item));\n");
            } else {
              tmp.add("        $key.add(item);\n");
            }
            tmp.add("      });\n");
          } else {
            if (object) {
              tmp.add("      $key = new $type.fromJson(json[\"$key\"]);\n");
            } else {
              tmp.add("      $key = json[\"$key\"];\n");
            }
          }
          tmp.add("    }\n");
        }
      });
    }
    tmp.add("  }\n\n");

    tmp.add("  /** Create JSON Object for $name */\n");
    tmp.add("  Map toJson() {\n");
    tmp.add("    var output = new Map();\n\n");
    if (data.containsKey("properties")) {
      data["properties"].forEach((key, property) {
        var schemaType = property["type"];
        bool array = false;
        bool object = false;
        var type;
        if (schemaType == "array") {
          array = true;
          schemaType = property["items"]["type"];
        }
        switch(schemaType) {
          case "object":
            type = "${capitalize(name)}${capitalize(key)}";
            object = true;
            break;
          case "string": type = "String"; break;
          case "number": type = "num"; break;
          case "integer": type = "int"; break;
          case "boolean": type = "bool"; break;
        }
        if (type == null) {
          object = true;
          if (array) {
            type = property["items"]["\$ref"];
          } else {
            type = property["\$ref"];
          }
        }
        if (type != null) {
          tmp.add("    if ($key != null) {\n");
          if (array) {
            tmp.add("      output[\"$key\"] = new List();\n");
            tmp.add("      $key.forEach((item) {\n");
            if (object) {
              tmp.add("        output[\"$key\"].add(item.toJson());\n");
            } else {
              tmp.add("        output[\"$key\"].add(item);\n");
            }
            tmp.add("      });\n");
          } else {
            if (object) {
              tmp.add("      output[\"$key\"] = $key.toJson();\n");
            } else {
              tmp.add("      output[\"$key\"] = $key;\n");
            }
          }
          tmp.add("    }\n");
        }
      });
    }
    tmp.add("\n    return output;\n");
    tmp.add("  }\n\n");

    tmp.add("  /** Return String representation of $name */\n");
    tmp.add("  String toString() => JSON.stringify(this.toJson());\n\n");

    tmp.add("}\n\n");

    subSchemas.forEach((subName, value) {
      tmp.add(_createSchemaClass(subName, value));
    });

    return tmp.toString();
  }

  /// Create a method with [name] inside of a class, based on [data]
  String _createMethod(String name, Map data) {
    var tmp = new StringBuffer();
    var upload = false;
    var uploadPath;

    if (data.containsKey("description")) {
      tmp.add("  /** ${data["description"]} */\n");
    }

    var params = new StringBuffer();
    var optParams = new StringBuffer();
    
    if (data.containsKey("request")) {
      params.add("${data["request"]["\$ref"]} request");
    }
    if (data.containsKey("parameterOrder") && data.containsKey("parameters")) {
      data["parameterOrder"].forEach((param) {
        if (data["parameters"].containsKey(param)) {
          var type = parameterType[data["parameters"][param]["type"]];
          if (type != null) {
            if (!params.isEmpty) params.add(", ");
            params.add("$type ${cleanName(param)}");
            data["parameters"][param]["gen_included"] = true;
          }
        }
      });
    }
    
    if (data.containsKey("mediaUpload")) {
      if (data["mediaUpload"].containsKey("protocols")) {
        if (data["mediaUpload"]["protocols"].containsKey("simple")) {
          if (data["mediaUpload"]["protocols"]["simple"].containsKey("multipart")) {
            if (data["mediaUpload"]["protocols"]["simple"]["multipart"] == true) {
              upload = true;
              uploadPath = data["mediaUpload"]["protocols"]["simple"]["path"];
            }
          }
        }
      }
    }
    
    if (upload) {
      optParams.add("String content, String contentType");
    }
    if (data.containsKey("parameters")) {
      data["parameters"].forEach((name, param) {
        if (!param.containsKey("gen_included")) {
          var type = parameterType[param["type"]];
          if (type != null) {
            if (!optParams.isEmpty) optParams.add(", ");
            optParams.add("$type ${cleanName(name)}");
          }
        }
      });
    }

    if (!optParams.isEmpty) { 
      if (!params.isEmpty) params.add(", ");
      params.add("{${optParams.toString()}}");
    }
    
    var response = null;
    if (data.containsKey("response")) {
      response = "Future<${data["response"]["\$ref"]}>";
    } else {
      response = "Future<Map>";
    }

    tmp.add("  $response $name($params) {\n");
    tmp.add("    var completer = new Completer();\n");
    tmp.add("    var url = \"${data["path"]}\";\n");
    if (upload) {
      tmp.add("    var uploadUrl = \"$uploadPath\";\n");
    }
    tmp.add("    var urlParams = new Map();\n");
    tmp.add("    var queryParams = new Map();\n\n");
    
    if (data.containsKey("parameters")) {
      data["parameters"].forEach((name, param) {
        var variable = cleanName(name);
        if (param["location"] == "path") {
          tmp.add("    if (?$variable && $variable != null) urlParams[\"$name\"] = $variable;\n");
        } else {
          tmp.add("    if (?$variable && $variable != null) queryParams[\"$name\"] = $variable;\n");
        }
      });
    }

    params.clear();
    if (data.containsKey("request")) {
      params.add("body: request.toString(), ");
    }
    params.add("urlParams: urlParams, queryParams: queryParams");
    
    
    tmp.add("    var response;\n");
    if (upload) {
      var uploadParams = new StringBuffer();
      if (data.containsKey("request")) {
        uploadParams.add("request.toString(), ");
      } else {
        uploadParams.add("\"\", ");
      }
      uploadParams.add("content, contentType, urlParams: urlParams, queryParams: queryParams");
      tmp.add("    if (?content && content != null) {\n");
      tmp.add("      response = _client._upload(uploadUrl, \"${data["httpMethod"]}\", ${uploadParams.toString()});\n");
      tmp.add("    } else {\n");
      tmp.add("      response = _client._request(url, \"${data["httpMethod"]}\", ${params.toString()});\n");
      tmp.add("    }\n");
    } else {
      tmp.add("    response = _client._request(url, \"${data["httpMethod"]}\", ${params.toString()});\n");
    }
    
    tmp.add("    response\n");
    tmp.add("    ..handleException((e) { completer.completeException(e); return true; })\n"); 
    tmp.add("    ..then((data) => ");
    if (data.containsKey("response")) {
      tmp.add("completer.complete(new ${data["response"]["\$ref"]}.fromJson(data)));\n");
    } else {
      tmp.add("completer.complete(data));\n");
    }
    tmp.add("    return completer.future;\n");
    tmp.add("  }\n");

    return tmp.toString();
  }

  String _createResourceClass(String name, Map data) {
    var tmp = new StringBuffer();
    var className = "${capitalize(name)}Resource";

    tmp.add("class $className extends Resource {\n");

    if (data.containsKey("resources")) {
      tmp.add("\n");
      data["resources"].forEach((key, resource) {
        var subClassName = "${capitalize(name)}${capitalize(key)}Resource";
        tmp.add("  $subClassName _$key;\n");
        tmp.add("  $subClassName get $key => _$key;\n");
      });
    }

    tmp.add("\n  $className._internal(Client client) : super(client) {\n");
    if (data.containsKey("resources")) {
      data["resources"].forEach((key, resource) {
        var subClassName = "${capitalize(name)}${capitalize(key)}Resource";
        tmp.add("  _$key = new $subClassName._internal(client);\n");
      });
    }
    tmp.add("  }\n");

    if (data.containsKey("methods")) {
      data["methods"].forEach((key, method) {
        tmp.add("\n");
        tmp.add(_createMethod(key, method));
      });
    }

    tmp.add("}\n\n");

    if (data.containsKey("resources")) {
      data["resources"].forEach((key, resource) {
        tmp.add(_createResourceClass("${capitalize(name)}${capitalize(key)}", resource));
      });
    }

    return tmp.toString();
  }

  String _createClientClass() {
    return """
part of $_name;

/**
 * Base class for all API clients, offering generic methods for HTTP Requests to the API
 */
abstract class Client {
  OAuth2 _auth;
  String _baseUrl;
  String _rootUrl;
  bool makeAuthRequests;
  Map _params;

  static const _boundary = "-------314159265358979323846";
  static const _delimiter = "\\r\\n--\$_boundary\\r\\n";
  static const _closeDelim = "\\r\\n--\$_boundary--";

  Client([OAuth2 this._auth]) {
    _params = new Map();
    makeAuthRequests = false;
  }

  /**
   * Send a HTTPRequest using [method] (usually GET or POST) to [requestUrl] using the specified [urlParams] and [queryParams]. Optionally include a [body] in the request.
   */
  Future _request(String requestUrl, String method, {String body, String contentType:"application/json", Map urlParams, Map queryParams}) {
    var request = new HttpRequest();
    var completer = new Completer();

    if (urlParams == null) urlParams = {};
    if (queryParams == null) queryParams = {};

    _params.forEach((key, param) {
      if (param != null) {
        queryParams[key] = param;
      }
    });

    var path;
    if (requestUrl.substring(0,1) == "/") {
      path ="\$_rootUrl\${requestUrl.substring(1)}";
    } else {
      path = "\$_baseUrl\$requestUrl";
    }
    final url = new UrlPattern(path).generate(urlParams, queryParams);

    request.on.loadEnd.add((Event e) {
      if (request.status == 200) {
        var data = JSON.parse(request.responseText);
        completer.complete(data);
      } else {
        var error = "";
        if (request.status == 0) {
          error = "Unknown Error, most likely related to same-origin-policies.";
        } else {
          if (request.responseText != null) {
            var errorJson;
            try {
              errorJson = JSON.parse(request.responseText); 
            } on FormatException {
              errorJson = null;
            }
            if (errorJson != null && errorJson.containsKey("error")) {
              error = "\${errorJson["error"]["code"]} \${errorJson["error"]["message"]}";
            }
          }
          if (error == "") {
            error = "\${request.status} \${request.statusText}";
          }
        }
        completer.completeException(new APIRequestException(error));
      }
    });

    request.open(method, url);
    request.setRequestHeader("Content-Type", contentType);
    if (makeAuthRequests && _auth != null) {
      _auth.authenticate(request).then((request) => request.send(body));
    } else {
      request.send(body);
    }

    return completer.future;
  }

  /**
   * Join [content] (encoded as Base64-String) with specified [contentType] and additional request [body] into one multipart-body and send a HTTPRequest with [method] (usually POST) to [requestUrl]
   */
  Future _upload(String requestUrl, String method, String body, String content, String contentType, {Map urlParams, Map queryParams}) {
    var multiPartBody = new StringBuffer();
    if (contentType == null || contentType.isEmpty) {
      contentType = "application/octet-stream";
    }
    multiPartBody
    ..add(_delimiter)
    ..add("Content-Type: application/json\\r\\n\\r\\n")
    ..add(body)
    ..add(_delimiter)
    ..add("Content-Type: ")
    ..add(contentType)
    ..add("\\r\\n")
    ..add("Content-Transfer-Encoding: base64\\r\\n")
    ..add("\\r\\n")
    ..add(contentType)
    ..add(_closeDelim);

    return _request(requestUrl, method, body: multiPartBody.toString(), contentType: "multipart/mixed; boundary=\\"\$_boundary\\"", urlParams: urlParams, queryParams: queryParams);
  }
}

/// Base-class for all API Resources
abstract class Resource {
  /// The [Client] to be used for all requests
  Client _client;

  /// Create a new Resource, using the specified [Client] for requests
  Resource(Client this._client);
}

/// Exception thrown when the HTTP Request to the API failed
class APIRequestException implements Exception {
  final String msg;
  const APIRequestException([this.msg]);
  String toString() => (msg == null) ? "APIRequestException" : "APIRequestException: \$msg";
}

""";
  }
}


Future<String> loadDocumentFromUrl(String url) {
  var completer = new Completer();
  var client = new HttpClient();
  var connection = client.getUrl(new Uri.fromString(url));
  var result = new StringBuffer();

  connection.onError = (error) => completer.complete("Unexpected error: $error");

  connection.onRequest = (HttpClientRequest request) {
    request.outputStream.close();
  };

  connection.onResponse = (HttpClientResponse response) {
    response.inputStream.onData = () {
      result.add(new String.fromCharCodes(response.inputStream.read()));
    };
    response.inputStream.onClosed = () {
      client.shutdown();
      completer.complete(result.toString());
    };
  };

  return completer.future;
}

Future<String> loadDocumentFromGoogle(String api, String version) {
  final url = "https://www.googleapis.com/discovery/v1/apis/${encodeUriComponent(api)}/${encodeUriComponent(version)}/rest";
  return loadDocumentFromUrl(url);
}

Future<String> loadDocumentFromFile(String fileName) {
  final file = new File(fileName);
  return file.readAsString();
}

void printUsage(parser) {
  print("discovery_api_dart_client_generator: creates a Client library based on a discovery document\n");
  print("Usage:");
  print("   generator.dart -a <API> - v <Version> [-o <Directory>] (to load from Google Discovery API)");
  print("or generator.dart -u <URL> [-o <Directory>] (to load discovery document from specified URL)");
  print("or generator.dart -i <File> [-o <Directory>] (to load discovery document from local file)");
  print("or generator.dart -all [-o <Directory>] (to create libraries for all Google APIs)\n");
  print(parser.getUsage());
}

void main() {
  final options = new Options();
  var parser = new ArgParser();
  parser.addOption("api", abbr: "a", help: "Short name of the Google API (plus, drive, ...)");
  parser.addOption("version", abbr: "v", help: "Google API version (v1, v2, v1alpha, ...)");
  parser.addOption("input", abbr: "i", help: "Local Discovery document file");
  parser.addOption("url", abbr: "u", help: "URL of a Discovery document");
  parser.addFlag("all", help: "Create client libraries for all Google APIs", negatable: false);
  parser.addOption("output", abbr: "o", help: "Output Directory", defaultsTo: "output/");
  parser.addFlag("date", help: "Create sub folder with current date", negatable: true, defaultsTo: true);
  parser.addFlag("help", abbr: "h", help: "Display this information and exit", negatable: false);
  var result;
  try {
    result = parser.parse(options.arguments);
  } on FormatException catch(e) {
    print("Error parsing arguments:\n${e.message}\n");
    printUsage(parser);
    return;
  }

  if (result["help"] != null && result["help"] == true) {
    printUsage(parser);
    return;
  }

  if ((result["api"] == null || result["version"] == null) && result["input"] == null && result["url"] == null && (result["all"] == null || result["all"] == false)) {
    print("Missing arguments\n");
    printUsage(parser);
    return;
  }

  var argumentErrors = false;
  argumentErrors = argumentErrors || (result["api"] != null && (result["input"] != null || result["url"] != null || (result["all"] != null && result["all"] == true)));
  argumentErrors = argumentErrors || (result["input"] != null && (result["url"] != null || (result["all"] != null && result["all"] == true)));
  argumentErrors = argumentErrors || (result["url"] != null && result["all"] != null && result["all"] == true);
  if (argumentErrors) {
    print("You can only define one kind of document source.\n");
    printUsage(parser);
    return;
  }
  
  var output = result["output"];
  if (result["date"] != null && result["date"] == true) {
    output = "$output/${fileDate(new Date.now())}";
  }
  
  if (result["all"] == null || result["all"] == false) { 
    var loader;
    if (result["api"] !=null)
      loader = loadDocumentFromGoogle(result["api"], result["version"]);
    else if (result["url"] != null)
      loader = loadDocumentFromUrl(result["url"]);
    else if (result["input"] != null)
      loader = loadDocumentFromFile(result["input"]);

    loader.then((doc) {
      var generator = new Generator(doc);
      generator.generateClient(output);
    });
  } else {
    loadDocumentFromUrl("https://www.googleapis.com/discovery/v1/apis").then((data) {
      var jsonData = JSON.parse(data);
      jsonData["items"].forEach((item) {
        loadDocumentFromUrl(item["discoveryRestUrl"]).then((doc) {
          var generator = new Generator(doc);
          generator.generateClient(output);
        });
      });
    });
  }
}