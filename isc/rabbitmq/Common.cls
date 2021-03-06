Class isc.rabbitmq.Common Extends %RegisteredObject [ Abstract ]
{

/// Either host or Connection URI: amqp:\\
/// If Connection URI is passed, then Port, Credentials and Virtual host properties are ignored.
Property Host As %VarString [ InitialExpression = "localhost" ];

Property Port As %Integer [ InitialExpression = -1 ];

Property VirtualHost As %String [ InitialExpression = "/" ];

/// Outbound adapter only (ignored for inbound adapter)
/// If Exchange is not set, then Queue name.
/// If Exchange is set, then Routing Key.
Property Queue As %String;

/// Exchange name.
/// Optional, empty by default.
/// If set, Queue becomes Routing Key.
Property Exchange As %String;

/// Config Name of the Java Gateway service controlling the Java Gateway server this item will use.
/// Alternatively use JGHost and JGPort Settings, to specify Java gateway outside of Ensemble scope.
Property JGService As %String;

/// Hostname of the Java Gateway server this item will use.
/// Alternatively use JGService Setting, to specify Java gateway inside Ensemble.
Property JGHost As %String;

/// Port of the Java Gateway server this item will use.
/// Alternatively use JGService Setting, to specify Java gateway inside Ensemble.
Property JGPort As %Integer;

/// Gateway connection
Property JGW As %Net.Remote.Gateway;

/// API object
Property API As isc.rabbitmq.API;

/// Encoding to convert message body. Leave empty to get/send as is.
Property Encoding As %String;

/// CLASSPATH containing the files required to be passed as an argument when starting the JVM.
/// The user should typically provide here the files containing the classes used via the Java Gateway. 
/// We assume that the user has properly quoted the classpath and supplied the correct separators for the platform
/// in case of multiple files. <br>
/// See property AdditionalPaths in that class.
Property ClassPath As %String(MAXLEN = 32000);

/// These are the production settings for this object
Parameter SETTINGS = "Host:Basic,Port:Basic,VirtualHost:Basic,Queue:Basic,Exchange:Basic,Credentials:Basic:credentialsSelector,JGHost:Java Gateway,JGPort:Java Gateway,JGService:Java Gateway:selector?context={Ens.ContextSearch/ProductionItems?targets=0&productionName=@productionId},ClassPath:Basic,Encoding:Basic";

/// Connect to running JGW 
Method Connect() As %Status
{
    // connect to current namespace, use 2 second timeout
    Set sc = $$$OK
    Set timeout = 5
    Set classPath = ##class(%ListOfDataTypes).%New()
    Do classPath.Insert(..ClassPath)

    // get a connection handle and connect
    Set gateway = ##class(%Net.Remote.Gateway).%New()
    If ..JGService'="" {
		Set host = ##class(Ens.Director).GetHostSettingValue(..JGService, "Address")
		Set port = ##class(Ens.Director).GetHostSettingValue(..JGService, "Port")
    } Else {
	    Set host = ..JGHost
		Set port = ..JGPort
    }
    
    Set sc = gateway.%Connect(host, port, $namespace, timeout, classPath)

    If $$$ISOK(sc) {
	    Set ..JGW = gateway
    }
    Quit sc
}

Method ConnectToRabbitMQ() As %Status
{
	Set sc = $$$OK
	
	If ..%CredentialsObj.Username'="" {
		Set user = ..%CredentialsObj.Username
		Set pass = ..%CredentialsObj.Password
	} Else {
		Set user = "guest"
		Set pass = "guest"
	}
	
	Try {
		If $IsObject(..API) {
			Do ..API.close()
			Set ..API = $$$NULLOREF
		}
		
		Set ..API = ##class(isc.rabbitmq.API).%New(..JGW, ..Host, ..Port, user, pass, ..VirtualHost, ..Queue, $$$YES, ..Exchange)
	} Catch ex {
		Set sc = ..ExceptionToStatus(ex)
	}
	
	Quit sc
}

/// Reserve Close connection. 
Method CloseConnection()
{
	#Include Ensemble
	if $IsObject(..API) {
		try {
				do ..API.close()
			} catch ex {
				set sc = ..ExceptionToStatus(ex)
				if $System.Status.GetErrorText(sc) [ "AlreadyClosedException" {
					$$$TRACE("Caught AlreadyClosedException")
					set sc = $$$OK
				} else {
					$$$LOGINFO($$$FormatText("CloseConnection unexpected exception: %1", $System.Status.GetErrorText(sc)))
					set ..API = $$$NULLOREF
					throw ex
				}
			}
		set ..API = $$$NULLOREF
	}
}

Method ExceptionToStatus(ex As %Exception.General) As %Status
{
	#Dim sc As %Status
	If ((ex.Name="<ZJGTW>") && $d(%objlasterror)) {
		Set sc = %objlasterror
	} Else {
		Set sc = ex.AsStatus()
	}
    Quit sc
}

}

