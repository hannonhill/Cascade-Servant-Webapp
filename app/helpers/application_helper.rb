# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

require 'socket'
require 'rexml/document'
include REXML
@@tomcat = "apache-tomcat-5.5.23"
@@pwd = "/home/cascade/servant"

def valid_server? server
  if server and FileTest.file? "#{server}/conf/server.xml"
    return true
  end
  return false
end

def dump(server)
  config = ServerConfig.new server
  puts "Dumping:   #{server}"
  puts "Database Name: #{config.values["db_name"]}"
  db2_name = config.values["db_name"]  
  system "mysqldump -u root  -f --max-allowed-packet=512m --host=mysql #{db2_name} > /home/cascade/latest#{server}dump.sql"
end

def create(server)
  return if not server
  system "tar xf #{@@tomcat}.tar"
  system "mv #{@@tomcat} #{server}"
  system "chmod -R o+r #{server}"
  config server
end

def database(server)
config = ServerConfig.new server
  puts "Importing Default Datbase into:   #{server}"
  puts "Database Name: #{config.values["db_name"]}"
  db2_name = config.values["db_name"]  

  system "mysqladmin -u root  -f --host=mysql create #{db2_name}"
  system "mysql -u root  --host=mysql -e 'alter database `#{db2_name}` default character set utf8 collate utf8_unicode_ci'"
  system "mysql -u root --default-character-set=utf8  --host=mysql #{db2_name} < /home/cascade/latestDefaultDump.sql"
  system "mysql -u root  --host=mysql -e 'grant all privileges on #{db2_name}.* to sales@\"%\" identified by \"sales\"'"
  system "mysql -u root  --host=mysql -e 'FLUSH PRIVILEGES;'"
end

def refresh(server)
  config = ServerConfig.new server
  puts "Dumping:   #{server}"
  puts "Database Name: #{config.values["db_name"]}"
  db2_name = config.values["db_name"]

 system "mysqladmin -u root  -f --host=mysql drop #{db2_name}"
 system "mysqladmin -u root  -f --host=mysql create #{db2_name}"
 system "mysql -u root  --host=mysql -e 'alter database `#{db2_name}` default character set utf8 collate utf8_unicode_ci'"
 system "mysql -u root --default-character-set=utf8  --host=mysql #{db2_name} < /home/cascade/latestDefaultDump.sql"
end

def install(server)
  @version
  return if not valid_server? server
  stop server
  print "What version you would like to install?\n\n"
  print "For a assistance type: help\n\n"
  confirm = gets.chomp  
  if (confirm == 'help')
  print "Use the exact version number.  i.e. 5.7.4, 6.0, etc..\n\n"
return
else
  version = confirm  
  system "rm -r #{server}/webapps/ROOT* > /dev/null 2>&1"
  system "scp servant@files:/usr/local/files/development/cascade/servant/war/ROOT#{version}.war #{server}/webapps/"
  system "mv #{server}/webapps/ROOT#{version}.war #{server}/webapps/ROOT.war" 
end
return
end

def remove(server)
  return if not valid_server? server
  print "Are you sure you want to remove the server #{server}? "
  confirm = gets.chomp
  
  if isrunning? server
    puts "ERROR: You can't remove this server until you stop it first"
    return
  end
  
  if (confirm[0].chr == 'y')
    system "rm -r #{server}"
  else
    puts "Aborting"
  end
end

def list
  puts "Listing servers\n\n"
  Dir.entries(@@pwd).each { |child|
    if child != "." && child != ".." && FileTest.directory?(child) then
      if valid_server? child
        server = child
        config = ServerConfig.new server
        puts "  * #{server} : #{status(server)}"
        puts "      - Port : #{config.values["httpport"]}"
        puts "      - DB: #{config.values["db_name"]}"
	puts ""
      end
    end
  }
end

def getAllServers
    servers = Array.new
    Dir.entries(@@pwd) { |child|
        if child != "." && child != ".." && FileTest.directory?(child) then
            if valid_server? child
                servers.inject(child)
            end
        end
    }
end

def status(server)
  begin
    return "RUNNING" if isrunning?(server)
    return "not running"
  rescue
    puts "Could not get status for #{server}: #{$!}"
  end
end

def isrunning?(server)
  port = getconnectorport server
  begin
    sock = TCPSocket.new("localhost",port)
    sock.close
    return true
  rescue
  end
  false
end

def getshutdownport(server)
  return if not valid_server? server
  File.open("#{server}/conf/server.xml") { |file| 
    doc = Document.new(file)
    root = doc.root
    element = root.elements['/Server']
    return element.attributes.get_attribute('port').to_s
  }
  nil
end

def getconnectorport(server)
  return if not valid_server? server
  File.open("#{server}/conf/server.xml") { |file| 
    doc = Document.new(file)
    root = doc.root
    element = root.elements['//Connector[position() = 1]']
    return element.attributes.get_attribute('port').to_s
  }
  nil
end

class ServerConfig
  attr :values
  
  def initialize(server)
    @server = server
    @values = Hash.new
    @drivers = { "mysql" => "com.mysql.jdbc.Driver", "mssql" => "net.sourceforge.jtds.jdbc.Driver", "oracle" => "oracle.jdbc.driver.OracleDriver"}
    
    # on construction, read the values for this server
    parse_port
    parse_database
  end
  
  def collect
    collect_port
    collect_database
  end
  
  def collect_port
    prompt_read "HTTP port         ? ", "httpport"
    @values["httpport"] = @values["httpport"].chomp.to_i
    @values["serverport"] = @values["httpport"] + 1
    @values["ajpport"] = @values["httpport"] + 2
    @values["redirectport"] = @values["httpport"] + 3
  end

  def parse_port
    if FileTest.file? "#{@server}/conf/server.xml" then
      xml = File.read "#{@server}/conf/server.xml"
      doc = Document.new xml
      @values["httpport"] = doc.root.elements['//Connector[position() = 1]'].attribute("port").to_s
    end
  end
  
  def collect_database
    prompt_read "Database username ? ", "db_username"
    prompt_read "Database password ? ", "db_password"
    prompt_read "Database driver   ? ", "db_driver"
    prompt_read "Database host     ? ", "db_host"
    prompt_read "Database port     ? ", "db_port"
    prompt_read "Database name     ? ", "db_name"
    
    @values["db_driverClassName"] = @drivers[@values["db_driver"]]
  end
  
  def prompt_read(prompt, key)
    print prompt 
    if @values[key] 
      print "[#{@values[key]}] "
    end
    value = gets.chomp
    if value != ""
      @values[key]=value
    end
  end
  
  # reads current values from an existing database configuration in context.xml
  def parse_database
    if FileTest.file? "#{@server}/conf/context.xml" then
      xml = File.read "#{@server}/conf/context.xml"
      doc = Document.new xml
      root = doc.root
      resource = XPath.first(root, "/Context/Resource");
      if resource
        atts = resource.attributes
        @values["db_username"] = atts.get_attribute("username").to_s
        @values["db_password"] = atts.get_attribute("password").to_s
        
        driverClass = atts.get_attribute("driverClassName").to_s
        @drivers.keys.each { |x|
          @values["db_driver"] = x if @drivers[x] == driverClass
        }
        parse_url atts.get_attribute("url").to_s, @values["db_driverClassName"]
      end
    else
      puts "No existing context.xml definition file found"
    end
  end
  
  def parse_url (url, driver)
    # we want to catch substrings like ://localhost:3306/cascade?
    url.scan(/\:\/\/(.*?)\:([0-9]+)\/(.*?)[\?;]/) { |host, port, dbname|
      @values["db_host"] = host
      @values["db_port"] = port
      @values["db_name"] = dbname
    }
  end
  
end

def config(server)
  return if not server
  stop server
  
  config = ServerConfig.new server
  config.collect
  
  write_serverxml server, config
  write_contextxml server, config
end

def write_contextxml(server, config)
  content = File.read("context.xml")
  
  if "oracle" == config.values["db_driver"]
    content.gsub!(/<!-- DB_SCHEMA -->/,"<ResourceLink name=\"schemaName\" global=\"cascadeSchemaName\" type=\"java.lang.String\"/>")
  end
  
  doc = Document.new(content)
  resource = doc.root.elements["/Context/Resource"]
  resource.add_attribute("username", config.values["db_username"])
  resource.add_attribute("password", config.values["db_password"])
  resource.add_attribute("driverClassName", config.values["db_driverClassName"])
  url = ""
  case config.values["db_driverClassName"]
  when "com.mysql.jdbc.Driver"
    url = "jdbc:mysql://" + config.values["db_host"] + ":" + config.values["db_port"] + "/" + config.values["db_name"]
    url+= "?useUnicode=true&amp;characterEncoding=UTF-8&amp;autoReconnect=true"
  when "net.sourceforge.jtds.jdbc.Driver"
    url = "jdbc:jtds:sqlserver://" + config.values["db_host"] + ":" + config.values["db_port"] + "/" + config.values["db_name"]
    url+= ";SelectMethod=cursor"
  when "oracle.jdbc.driver.OracleDriver"
    url = "jdbc:oracle:thin:@#{config.values['db_host']}:#{config.values['db_port']}:orcl"
  else
    puts "WARNING: unrecognized driver: #{config.values['db_driverClassName']}"
  end
  resource.add_attribute("url", url)
  File.open("#{server}/conf/context.xml","w") { |file|
    file.puts doc
  }
end

def write_serverxml(server, config)
  return if not valid_server? server
  content = File.read("server.xml")
  
  if "oracle" == config.values["db_driver"]
    content.gsub!(/<!-- DB_SCHEMA -->/,"<Environment name=\"cascadeSchemaName\" type=\"java.lang.String\" value=\"#{config.values['db_name']}\"/>")
  end
  
  doc = Document.new(content)
  doc.root.add_attribute("port", config.values["serverport"])
  doc.root.elements['//Connector[position() = 1]'].add_attribute("port", config.values["httpport"])
  doc.root.elements['//Connector[position() = 2]'].add_attribute("port", config.values["ajpport"])
  doc.root.elements['//Connector[position() = 1]'].add_attribute("redirectPort", config.values["redirectport"])
  doc.root.elements['//Connector[position() = 2]'].add_attribute("redirectPort", config.values["redirectport"])
  
  pretty = ""
  doc.write pretty,0
  File.open("#{server}/conf/server.xml", "w") { |file|
    file.puts pretty
  }
end

def start(server)
  return if not valid_server? server
  if not isrunning?(server)
    command = "#{@@pwd}/#{server}/bin/startup.sh > /dev/null 2>&1"
    forkandrun command
  end
end

def jpda(server)
  return if not valid_server? server
  if not isrunning?(server)
    port = getconnectorport server
    jpdaport = port.to_i + 10
    puts "Using JPDA port of #{jpdaport}"
    command = "export JPDA_ADDRESS=#{jpdaport}; #{@@pwd}/#{server}/bin/catalina.sh jpda start > /dev/null 2>&1"
    forkandrun command
  end
end

def forkandrun(command)
  pid1 = fork do

    Process.setsid()
    File.umask(0)

    pid2 = fork do
      exec command
    end

    Process.exit!(0)
  end
end

def stop(server)
  return if not valid_server? server
  if isrunning? server
    system "#{server}/bin/shutdown.sh > /dev/null 2>&1"
  end
end

def log(server)
  return if not valid_server? server
  system "less #{server}/logs/catalina.out"
end

def tail(server)
  return if not valid_server? server
  system "tail -f #{server}/logs/catalina.out"
end

def printhtml
  puts "<p><ul>"
  Dir.entries(@@pwd).each { |child|
    if child != "." && child != ".." && FileTest.directory?(child) then
      if valid_server? child
        server = child
        puts "<b>#{server}</b> - #{status(server)}"
      end
    end
  }
  puts "</ul></p>"
end

trap("INT") {
  puts "Interrupt caught.. Everyone out!"
  exit 0
}

if ARGV.size == 1 and "printhtml" == ARGV[0]
  printhtml
  exit 0
end

end
