use strict;
use warnings;
use Config::Simple;
#use Data::Dumper; # Only needed for debugging xml data
use XML::Simple;
use LWP::Simple;
use XML::Simple qw(:strict);
use Time::Piece;
use Net::Ping;
use DBI;

##  NOTES
## Software: strawberry perl 5.30.1.1-32, mysql-8.0.18.0, 
##
##  Severity values - Emergency-0, Alert-1,Critical-2, Error-0, Warning-4, Notice-6,Informational-8, Debug-10, 
##  Message Type - Telnet, SSH, Database, File...
#### XML endpoints
# Current Status http://x.x.x.x/cgi-bin/status.xml
# Data Log http://x.x.x.x/cgi-bin/datalog.xml
# Outlets http://x.x.x.x/cgi-bin/outlog.xml
# Program http://x.x.x.x/cgi-bin/program.xml
#
#
## Current issues
## Not breaking out of script if no input command is provided
## No value on Database and csv log values on no input value
## No outlet / program output to csv file

my ($DeviceID,$Serevity,$MessageType,$Message); ## Logging variables ($DeviceID,$Serevity,$MessageType,$Message);
Logging($DeviceID = 0 ,$Serevity = 8,$MessageType = "File System",$Message = "Loading script variables");

# Open cfg file for varialbles
my $cfg = new Config::Simple();
	$cfg->read('apex.cfg') or Logging($DeviceID =0 ,$Serevity = 1,$MessageType = "File System",$Message = "$cfg->error()");

## Data StorageLocation
our $LogDatabase = $cfg->param("DataStorage.database");
my $LogFile = $cfg->param("DataStorage.file"); ## Log file option yes/no
my $StorageFolder = $cfg->param("DataStorage.folder"); ## logging fiolder location
my $SyslogFileLocation = $cfg->param("DataStorage.folder") . $cfg->param("DataStorage.syslogfile"); # syslog file
my $DeviceFileLocation = $cfg->param("DataStorage.folder") . $cfg->param("DataStorage.devicefile"); # Device log file
my $ProbeFileLocation  = $cfg->param("DataStorage.folder") . $cfg->param("DataStorage.probefile");  # Probe log file
my $OutletFileLocation = $cfg->param("DataStorage.folder") . $cfg->param("DataStorage.outletfile"); # OUtlet log file

## Database properties
my $Dbase_host = $cfg->param("mysql.host");
my $Dbase_db = $cfg->param("mysql.db");
my $Dbase_User = $cfg->param("mysql.user");
my $Dbase_Psswd = $cfg->param("mysql.passwd");  

## Logging properties
my $Debug = $cfg->param("Logging.Debug"); # Debugging status
my $Sev = $cfg->param("Logging.Severity");

## Apex login 
my $Apex_Login;  ## Not used yet, used for when user/password is required
my $Apex_Paswd;  ## Not used yet, used for when user/password is required

## Help info
my $HelpText = "
---------------------------------------HELP-----------------------------------------
usage: perl Apex_Poller.pl -[a-z]
Example: perl Apex_Poller -h
commands
-c = Apex data collector
-h Help
------------------------------------------------------------------------------------
";


### Starting script
Logging($DeviceID =0 ,$Serevity = 8,$MessageType = "Script",$Message = "Starting script");


## Input arguments
my ($option, $number) = @ARGV;
	if (not defined $option) {
		 Logging($DeviceID =0 ,$Serevity = 1, $MessageType = "Script",$Message = "Please include an script input option");
		 Logging($DeviceID =0 ,$Serevity = 8, $MessageType = "Script",$Message = "Exiting Script");
		exit();
	}

## Show option
Logging($DeviceID =0 ,$Serevity = 8, $MessageType = "Script",$Message = "Option selected $option");


## Show debugging status
if ($Debug > 0) {
	 Logging($DeviceID =0 ,$Serevity = 8, $MessageType = "Script",$Message = "Debugging is enabled with status $Debug");
	}
	else
	{
	 Logging($DeviceID =0 ,$Serevity = 8, $MessageType = "Script",$Message = "Debugging is Disabled with status $Debug");	
	}



#######################
##  APEX COLLECTION	 ##
##	   OPTIONS       ##
#######################

## Option '-c' Collect Apex Data
	if ($option eq '-c') {
			if ($Debug > 0) {
			Logging($DeviceID = 0 ,$Serevity = 8, $MessageType = "Script", $Message = "Running Option -c Apex data collection");
			}

		Get_Devices(); ## Collect probe and alarm logs for every device in list

	}

	elsif ($option eq '-h') {
		print $HelpText;

		}

	else
		 {
			Logging($DeviceID = 0 ,$Serevity = 1, $MessageType = "Script", $Message = "Please enter a vailid option.  Use -h for help");
			 exit(1);
		 }
Logging($DeviceID =0 ,$Serevity = 8,$MessageType = "Script",$Message = "Script ended");



##################
### SUBS START ###
##################


sub Get_Devices { ## Get Device list and gather data
Logging($DeviceID = 0 ,$Serevity = 8, $MessageType = "Script", $Message = "Starting sub get device list");

my $dbh = DBI->connect("DBI:mysql:$Dbase_db;host=$Dbase_host", 
                       "$Dbase_User", "$Dbase_Psswd", { RaiseError => 1 } ) or
							Logging($DeviceID =0 ,$Serevity = 1,$MessageType = "Database",$Message = getTimeStamp() . " Error:Couldn't connect to database:  DBI->errstr ");

	my $sth = $dbh->prepare('CALL get_activedevices();'); ## sproc to get active list of APEX devices

	$sth->execute();  ## Execute query

	while (my @dbrow = $sth->fetchrow_array() ) {
		   my $Apex_ID = $dbrow[0];
		   my $DeviceName = $dbrow[1];	   
		   my $DeviceIP = $dbrow[2];  
		   my $ApexUser = $dbrow[3] // 'NULL';
		   my $ApexPwd = $dbrow[4] // 'NULL';
		   my $DetectedSerial = $dbrow[5] // 'NULL'; # Added // default value NULL for accounting
		   my $DetectedVersion = $dbrow[6] // 'NULL'; # Added // default value NULL for accounting	   

Logging($DeviceID = $Apex_ID ,$Serevity = 10,$MessageType = "Device",$Message = "Found Apex\n----------\nDevice ID: $Apex_ID\nDevice Name: $DeviceName\nIP: $DeviceIP\nUser: $ApexUser\nPassword: $ApexPwd\nDetected Serial: $DetectedSerial\nDetected Version: $DetectedVersion\n-------\n\n");
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Device",$Message = "Found Device ID:$Apex_ID IP:$DeviceIP in Database");


my $timeout = 2;
my $ping = Net::Ping->new("icmp");
# perform the ping
	if( $ping->ping($DeviceIP, $timeout) )  {
				Logging($DeviceID = "$Apex_ID",$Serevity = 8,$MessageType = "Device",$Message = "Device Pingable: ID:$Apex_ID IP:$DeviceIP");
				Collect_Status("$DeviceIP","$Apex_ID","$DetectedSerial"); ## Collect Device Data		
		}
		
		
		else
			{
					Logging($DeviceID = "$Apex_ID",$Serevity = 3,$MessageType = "Device",$Message = "Device is NOT Pingable: ID:$Apex_ID IP:$DeviceIP, Skipping device!!!");
					next;
			}

	# close ping
	$ping->close(); # Close ping session

	}

Logging($DeviceID = "0",$Serevity = 8,$MessageType = "Database",$Message = "Finished data collection for all active devices.");
Logging($DeviceID = "0",$Serevity = 8,$MessageType = "Script",$Message = "Exiting Script.");  
exit();
} ## END SUB



sub Collect_Status {
my $Apex_IP = shift;
my $Apex_ID = shift;
my $Detected_Serial = shift;

my $Db_DateTime;
my $URI = "http://$Apex_IP/cgi-bin/status.xml";

# create object
	my $xml = new XML::Simple;
	my $content = get $URI or Logging($DeviceID = $Apex_ID,$Serevity = 1,$MessageType ="Poll",$Message = "Unable to access URL: $URI");
	my $data = $xml->XMLin($content, ForceArray=>0,KeyAttr=>{});
	## Basic Data
	  my $Software = $data->{software};##Software Version
	  my $Hardware = $data->{hardware};## Hardware Version
	  my $Hostname = $data->{hostname};## Hardware Version
	  my $Serial = $data->{serial};## Serial
	  my $PollDate =  $data->{date};## Poll Date	
	  my $Timzone = $data->{timezone};## timezone
	  my $PowerFailed = $data->{power}->{failed};## Failed Power
	  my $PowerRestored = $data->{power}->{restored}; ## Restored Power
	## DEBUG MODE  
	 if ($Debug > 0) {
			print "Software: $Software\n";
			print "Hardware: $Hardware\n";
			print "Hostname: $Hostname\n";
			print "Serial: $Serial\n";
			print "Poll Date: $PollDate\n";
			print "Power Failed: $PowerFailed\n";
			print "Power Restored: $PowerRestored\n\n";
		} ## END IF Statement

## Check if detected SN is the same as the actual SN and update database

	if ($Detected_Serial eq $Serial) {
		Logging($DeviceID = $Apex_ID,$Serevity = 3,$MessageType ="Poll",$Message = "Device Serial Number and Serial Number in Database match. Database: $Serial Detected: $Detected_Serial");
	} 
#		
	elsif ($Detected_Serial eq 'NULL') {
		Logging($DeviceID = $Apex_ID,$Serevity = 3,$MessageType ="Poll",$Message = "NULL Serial Number detected in Database. Database: $Serial Detected: $Detected_Serial");
	}
#
	else {
		if ($Debug > 0) {
		Logging($DeviceID = $Apex_ID,$Serevity = 3,$MessageType ="Poll",$Message = "Error: Device Serial Number and database device Serial Number don't match Database: $Serial Detected: $Detected_Serial");
		}

	}	## IF END	
	
	

## Log Device History
	my $Db_PowerRestored;	
		## Added to solve for value "none" in power restored field
		if ($PowerRestored eq 'none') {
				$Db_PowerRestored = '1999-01-01 00:00:00';
				Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Poll",$Message = "Detected value NONE in power restore date.  Changing date to $Db_PowerRestored");			
			} 
		else
			{
			    $Db_PowerRestored = Convert_date("$PowerRestored"); 
				Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Poll",$Message = "Detected valid power resotre date, using date $Db_PowerRestored");
			}
			
	my $Db_PowerFailed = Convert_date("$PowerFailed"); ## Converting apex date to mysql date format
	my $Db_Poll = Convert_date("$PollDate"); ## Converting apex date to mysql date format

	## Insert data into database
	my $dbh = DBI->connect("DBI:mysql:$Dbase_db;host=$Dbase_host", 
					"$Dbase_User", "$Dbase_Psswd", { RaiseError => 1 } ) or
					Logging($DeviceID = $Apex_ID,$Serevity = 1,$MessageType ="Database",$Message = "Couldn't connect to database: " . DBI->errstr);
					
				my $query = "insert into history_device (deviceid, detected_name,detected_serial,detected_software,detected_hardware,last_power_fail,last_power_restore,poll_date) 
					values (?,?,?,?,?,?,?,?)";
				my $statement = $dbh->prepare($query);
					$statement->execute("$Apex_ID","$Hostname", "$Serial", "$Software", "$Hardware", "$Db_PowerFailed", "$Db_PowerRestored", "$Db_Poll");
		
		
	
## If detected values are NULL update device details
## Pending next release

## If Apex name changed update device details
## Pending next release


## Collect probe data
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Poll",$Message = "Starting to collect probe data");
	
## Get Probe Values
	for my $n ( @{$data->{probes}->{probe}} ) {
		my $Name = $n->{name};
		my $Type = $n->{type} // 'NULL';
		my $Value = $n->{value} // 'NULL';
		$Db_DateTime = Convert_date("$PollDate");		
			if ($Debug > 0) {
				Logging($DeviceID = $Apex_ID,$Serevity = 10,$MessageType ="Data",$Message = "Probe Name: $Name, Type: $Type, Value: $Value, Poll Date: $Db_DateTime");	
			} ## END IF Statement
		
			## Insert data into database
				my $dbh = DBI->connect("DBI:mysql:$Dbase_db;host=$Dbase_host", 
						"$Dbase_User", "$Dbase_Psswd", { RaiseError => 1 } ) or
							Logging($DeviceID = $Apex_ID,$Serevity = 1,$MessageType ="Data",$Message = "Couldn't connect to database: " . DBI->errstr );

					my $query = "insert into history_probes (deviceid, probe_name,probe_type,probe_value,polldate) 
						values (?,?,?,?,?)";
					my $statement = $dbh->prepare($query);
						$statement->execute("$Apex_ID", "$Name", "$Type", "$Value","$Db_DateTime");	
	} ## Loop END
$dbh->disconnect;
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Data",$Message = "completed Collecting probe data" );
	

## Collect outlet data
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Data",$Message = "Starting to collect outlet data" );

my ($Xstatus,$DeviceID,$Name,$State,$OutputID);
		for my $n1 ( @{$data->{outlets}->{outlet}} ) {
		## Check for null values due to NULL values to stop null value warning	
			$Xstatus = $n1->{xstatus} // '';
			$DeviceID = $n1->{deviceID} // '';
			$Name = $n1->{name} // '';
			$State = $n1->{state} // '';
			$OutputID = $n1->{outputID} // '';
			$Db_DateTime = Convert_date("$PollDate");
		## Show data if in debug mode
				if ($Debug > 0) {		
						Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Data",$Message = "Device Name: $Name, Device ID: $DeviceID, State: $State, X State: $Xstatus, OutputID: $OutputID, Poll Date: $Db_DateTime" );			
					} ## IF END
							
					## Insert data into database
					my $dbh = DBI->connect("DBI:mysql:$Dbase_db;host=$Dbase_host", 
						   "$Dbase_User", "$Dbase_Psswd", { RaiseError => 1 } ) or
								Logging($DeviceID = $Apex_ID,$Serevity = 1,$MessageType ="Data",$Message = "Couldn't connect to database: " . DBI->errstr );
					my $query = "insert into history_outlets (apexid,Outlet_Name,Outlet_State,Outlet_Xstatus,outlet_outputid,Outlet_PollDate) 
							values (?, ?, ?, ?, ?, ?) ";
					my $statement = $dbh->prepare($query);
							$statement->execute("$Apex_ID", "$Name", "$State","$Xstatus","$OutputID","$Db_DateTime");		
								
					
	} ## Loop END 
	$dbh->disconnect;
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Data",$Message = "Completed collecting outlet data" );
Logging($DeviceID = $Apex_ID,$Serevity = 8,$MessageType ="Data",$Message = "Complted collecting current status data" );	
}  ## SUB END


sub Convert_date {
	my $in_date = shift;
	my ($month, $day, $year, $hour, $minute,$second) = $in_date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d)\s(\d\d):(\d\d):(\d\d)/;
	my $Db_DateTime = "$year-$month-$day $hour:$minute:$second";
		return $Db_DateTime;
}


	
	
	
sub Logging {
use DBI;
use POSIX qw(strftime);
my $mydatetime = strftime "%Y-%m-%d %H:%M:%S",localtime;

## Logging($DeviceID = ,$Serevity = 8,$MessageType "",$Message = "");
##  Severity values - Emergency-0, Alert-1,Critical-2, Error-0, Warning-4, Notice-6,Informational-8, Debug-10, 
##  Message Type - Telnet, SSH, Database, File...
## Database info

## EventLog Info
my $DeviceID = shift;
my $Severity = shift;
my $MessageType = shift;
my $Message = shift;


##  Database Logging
if ($LogDatabase eq "yes") {
	my $dbs = DBI->connect("DBI:mysql:$Dbase_db;host=$Dbase_host", 
                       "$Dbase_User", "$Dbase_Psswd", { RaiseError => 1 } ) or die ( "Couldn't connect to database: " . DBI->errstr ); 
	$dbs->do("INSERT INTO logging (deviceid,severity,messagetype,message,timestamp)
						VALUES ('$DeviceID','$Serevity','$MessageType','$Message','$mydatetime')");						
	$dbs->disconnect;

		if ($Severity <= $Sev) {
			print getTimeStamp() . ",SEVERITY=$Severity,MessageType=$MessageType,Message=$Message\n";
			}
	}		

## File CSV Logging
if ($LogFile eq 'yes') {
		## print LogOutput getTimeStamp() . "$mydatetime $Severity $MessageType $Message\n";
		
		#### Open File 

		### write to file
		open(my $LogOutput, '>>', $SyslogFileLocation) or die "Could not open file '$SyslogFileLocation' $!";
			
			##print $LogOutput "TimeStamp," . getTimeStamp() . ",SEVERITY=$Severity,MessageType=$MessageType,Message=$Message\n"; ## For testing
			close $LogOutput;
		


		if ($Severity <= $Sev) {
			#print getTimeStamp() . ",SEVERITY=$Severity,MessageType=$MessageType,Message=$Message\n"; ## For testing
			}

}
		
}	




sub getTimeStamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $timestamp;
}


	
##################
### SUBS end   ###
##################	
	
	