About: This is a perl script that logs Probe and Outlet data from the Neptune Apex controller


Installation:
1) Install all the below programs

2) Create a directory for the scripts and extract the files to that folder. Example c:\Apex\

3) Create the MySql Database, tables and user account vis sql files
-- Update the file called Create_NewDatabase by changing the database username and password
-- Update the file called Create_NewDevice.sql with you APEX name and ip address

4) Update the apex.cfg file with your mysql username and password if you changed the default account in the sql files

5) Setup a Scheduled task or CRON job to run Apex_Poller.pl.  Example Apex_Poller.pl -c


Notes:  Must run script as admin due to using ICMP to check device status in windows.  Also the login fuction is not built and you must allow all xml connections inder
Apex Network Setup > Open XML Access - enable



##### Required Programs #####
-strawberry perl

-Per Plugins
--Config::Simple;
--XML::Simple;
--LWP::Simple;
--XML::Simple qw(:strict);
--Time::Piece;
--Net::Ping;
--DBI;

-MySql
-