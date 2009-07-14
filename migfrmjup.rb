#!/usr/local/bin/ruby
require 'net/scp'
require 'net/ssh'
class Migration
def initialize
  puts "Enter the svnrepository username(excluding 's_')\n"
  @path =gets.chomp.sub(/^/,'s_').sub(/^/,'/home/')#.sub(/$\n/,'')
  @spath = @path.sub(/$/,'/svn').to_sym
  @tpath = @path.sub(/$/,'/tracdb').to_sym
  @srepo = []
  @trac = []
  @schoice = []
  @tchoice = []
  @smap = {}
  @tmap = {}
  puts "Enter the domain name for the control panel(xyz.sourcerepo.com)"
  @host =gets.chomp.to_sym #sub(/$\n/,'').to_sym
  @username =@host.to_s.scan(/^\w+/).to_s
  @srpath =@username.sub(/^/,"/home/svn/repositories/").to_sym
  @trpath = @username.sub(/^/,"/var/trac/").to_sym
  puts "Please place the pub key of this server on the destination server\n\n"
  system("cat /root/.ssh/id_rsa.pub")
end

def fetch
  begin
  Dir.foreach(@spath.to_s){|x| @srepo << x if x !='.' && x !='..'}
  Dir.foreach(@tpath.to_s){|x| @trac << x if x !='.' && x !='..' }
  self.listing
  rescue Exception => e
  puts e
  end
end
def listing
  puts "\nListing available Repositories"
  puts :"***********************"
  if @srepo.length !=0
    @srepo.each{|x| print @srepo.index(x)+1,"\t",x,"\n"}
    puts :"***********************"
    puts "\nEnter the number's corresponding to repo's or just all to take the dupms(1,2,3 or all)\n"
    @schoice= gets.scan(/(\d+(, )?)|([aA][lL][lL])/).flatten.compact
   @schoice.each{|x| @schoice=(1..@srepo.length).to_a if(x =~ /[aA][lL][lL]/)}
  else
    puts "No Repos available"
    puts :"***********************"
  end
@schoice.uniq!
  puts "\nListing available Trac instances"
  puts "***********************"

  if @trac.length !=0
    @trac.each{|x| print @trac.index(x)+1,"\t",x,"\n"}
    puts :"***********************"
    puts "\nEnter the number corresponding to Trac or just all to take the dupms(1,2,3 or all)"
    @tchoice = gets.scan(/(\d+(, )?)|([aA][lL][lL])/).flatten.compact
    @tchoice.each{|x| @tchoice=(1..@trac.length).to_a if(x =~ /[aA][lL][lL]/)}
  else
  puts :"No Trac instances avilable"
  puts :"***********************"
  end
@tchoice.uniq!
  self.map if(@schoice.length !=0||@tchoice.length !=0)
end

def map
if(@schoice.length !=0)
  puts "Listing the Repository name mapping"
  @schoice.each do |x| @smap["#{@srepo[x.to_i-1]}"] = "#{@srepo[x.to_i-1]}"end
  @smap.each{|x,y| puts x+ "\t-->\t" +y}
  puts "\nDo you want to edit the mapping\n"
  if(gets.chomp=="yes")
  @smap.each{|x,y| print x+ "\t-->\t"
  @smap[x]=gets.chomp}
  end
  puts "\nThe final Repo mapping is"
  @smap.each{|x,y| puts  x+ "\t-->\t" +y}
end
if(@tchoice.length !=0)
  puts "\nListing the trac name mapping"
  @tchoice.each do |x| @tmap["#{@trac[x.to_i-1]}"] = "#{@trac[x.to_i-1]}"
end
  @tmap.each{|x,y| puts x+ "\t-->\t" +y}
  puts "\nDo you want to edit the Trac mapping\n"
  if(gets.chomp=="yes")
  @tmap.each{|x,y| print x+ "\t-->\t"
  @tmap[x]=gets.chomp}
  end
  puts "\nThe final Trac mapping is"
  @tmap.each{|x,y| puts  x+ "\t-->\t" +y}
end
self.start_mig
end

def start_mig
#  if @tchoice.length !=0||@schoice.length !=0
    @dumpfolder  = Time.now.to_s.gsub(/\W/,'').slice(0..13)
    @dumppath = (@path +"/"+@dumpfolder).to_sym
    Dir.mkdir(@dumppath.to_s)
    if @schoice.length !=0
      @schoice.each do |x|
      system("svnadmin   dump #{@spath}/#{@srepo[x.to_i-1]} > #{@dumppath}/#{@srepo[x.to_i-1]}.dump")
      end
    end
    if @tchoice.length !=0
      @tchoice.each do |x|
      system("sqlite #{@tpath}/#{@trac[x.to_i-1]}/db/trac.db .dump | sqlite3 #{@tpath}/#{@trac[x.to_i-1]}/db/trac-#{@dumpfolder}.db && mv #{@tpath}/#{@trac[x.to_i-1]}/db/trac-#{@dumpfolder}.db #{@dumppath}/#{@trac[x.to_i-1]}.trac")
      end
    end
    if system("cd #{@path} && tar -cvf #{@dumpfolder}.tar #{@dumpfolder}")
      puts "Successfully Packed"
      self.send_data
    end
#  else
#    puts "No INPUT given"
#  end
end

def send_data
  begin
  Net::SCP.upload!(@host.to_s,:"root",@dumppath.id2name+".tar", "/root")
  puts "Dumps sent successfully to /root/#{@dumpfolder}.tar"
  self.rolloff
  self.after_send
  rescue Exception => e
  self.rolloff
  puts e
  end
end

def after_send
  Net::SSH.start(@host.to_s,"root") do |ssh|
    if ssh.exec!("cd /root && tar -xvf #{@dumpfolder}.tar")
      puts "Successfully UnTarred"
    end
    if @schoice.length !=0
      @schoice.each do |x|
   ssh.exec!("mv #{@srpath}/#{@smap[@srepo[x.to_i-1]]} #{@srpath}/#{@smap[@srepo[x.to_i-1]]}.#{@dumpfolder}")
   ssh.exec!("svnadmin create #{@srpath}/#{@smap[@srepo[x.to_i-1]]}")
   puts "Successfully Moved the old repository #{@smap[@srepo[x.to_i-1]]} to #{@smap[@srepo[x.to_i-1]]}.#{@dumpfolder}"
   ssh.exec!("svnadmin load #{@srpath}/#{@smap[@srepo[x.to_i-1]]} < /root/#{@dumpfolder}/#{@srepo[x.to_i-1]}.dump")
   puts "Successfully Imported repository #{@smap[@srepo[x.to_i-1]]}"
   ssh.exec!("chown apache:admin #{@srpath}/#{@smap[@srepo[x.to_i-1]]} -R")
   puts "Restored permissions for the repository #{@smap[@srepo[x.to_i-1]]}\n\n"
   ssh.exec!("trac-admin #{@trpath}_#{@smap[@srepo[x.to_i-1]]} resync")
      end
    end
    if @tchoice.length !=0
      @tchoice.each do |x|
         ssh.exec!("mv #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db.#{@dumpfolder}")
         puts "Successfully Moved old Trac DB #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db to #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db.#{@dumpfolder}"
         ssh.exec!("cp /root/#{@dumpfolder}/#{@trac[x.to_i-1]}.trac #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db")
         puts "Successfully copied new DB"
         ssh.exec!("chown admin:apache #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db && chmod 660 #{@trpath}_#{@tmap[@trac[x.to_i-1]]}/db/trac.db")
         ssh.exec!("trac-admin #{@trpath}_#{@tmap[@trac[x.to_i-1]]} resync")
         puts "Restored permissions and Resynced Trac for #{@trpath}_#{@tmap[@trac[x.to_i-1]]}\n\n"
      end
    end
  ssh.exec!("rm -rf /root/#{@dumpfolder}*")
  end
end
def rolloff
        system("rm -rf #{@dumppath}*")
end

end

mig = Migration.new
mig.fetch

