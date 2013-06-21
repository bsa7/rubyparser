# encoding: utf-8
require 'open-uri'
require 'uri'
require 'mechanize'
require 'unicode'
require 'colorize'
#require 'yaml'
require 'psych'

#Библиотека классов

class String

 alias / :split

 def empty?
  if (self=="")
   true
  else
   false
  end
 end

 def removebrakets
  self.gsub('[',"").gsub(']',"").gsub('(',"").gsub(')',"").gsub('<',"").gsub('>',"")
 end

 def removedups
  notdupchars=".,: "
  str1=self.clone
  loop do
   str2=str1.clone
   notdupchars.size.times do |n|
    str2=str2.gsub(notdupchars[n]*2, notdupchars[n])
   end
   break if (str2==str1)
   str1=str2.clone
  end
  return str1
 end

 def removeeols
  self.gsub(/\s*\n\s*/,',').gsub(/\r/,'')
 end

 def cleareols
  self.gsub(/\s*\n\s*/,'').gsub(/\r/,'')
 end

 def cleaneols
  self.gsub(/\s*\n\s*/,'').gsub(/\r/,'')
 end

 def downcase
  Unicode::downcase(self)
 end

 def downcase!
  self.replace downcase
 end

 def upcase
  Unicode::upcase(self)
 end

 def upcase!
  self.replace upcase
 end

 def capitalize
  Unicode::capitalize(self)
 end

 def capitalize!
  self.replace capitalize
 end

 def black;          "\033[30m#{self}\033[0m" end
 def red;            "\033[31m#{self}\033[0m" end
 def green;          "\033[32m#{self}\033[0m" end
 def brown;          "\033[33m#{self}\033[0m" end
 def blue;           "\033[34m#{self}\033[0m" end
 def magenta;        "\033[35m#{self}\033[0m" end
 def cyan;           "\033[36m#{self}\033[0m" end
 def gray;           "\033[37m#{self}\033[0m" end
 def bg_black;       "\033[40m#{self}\0330m"  end
 def bg_red;         "\033[41m#{self}\033[0m" end
 def bg_green;       "\033[42m#{self}\033[0m" end
 def bg_brown;       "\033[43m#{self}\033[0m" end
 def bg_blue;        "\033[44m#{self}\033[0m" end
 def bg_magenta;     "\033[45m#{self}\033[0m" end
 def bg_cyan;        "\033[46m#{self}\033[0m" end
 def bg_gray;        "\033[47m#{self}\033[0m" end
 def bold;           "\033[1m#{self}\033[22m" end
 def reverse_color;  "\033[7m#{self}\033[27m" end
end

###########################################################################################
# Тестирование шаблонов соответствия ссылок
###########################################################################################
def testpattern regstr, str
 if regstr.match str
#  puts "#{str}==#{regstr}?".green
 else
  puts "#{str}==#{regstr}?".red
 end
end #testpattern regstr, str

###########################################################################################
# Проверить URL на присутствие недопустимых символов
# <схема>://<логин>:<пароль>@<хост>:<порт>/<URL путь>?<параметры>#<якорь>
###########################################################################################
def checkurl url
 validated=true
 notenabled = ["!", "\"", "%", "'", "*", "<", ">", "[", "]", "^", "`", "{", "}", "|", "\s"]
 notenabled.each do |symbl|
  if url[symbl]
   validated=false
   break
  end
 end
 return validated
end


###########################################################################################
# Реконструктор URL по известной базовой ссылке Node['baseurl'], известной по текущей открытой странице (currpath) текущей папке и произвольной относительной url
# <схема>://<логин>:<пароль>@<хост>:<порт>/<URL путь>?<параметры>#<якорь>
###########################################################################################
def reconstructurl url, currpath=""
 url_currpath=URI(currpath.gsub(/\/(\w|-|\.|\?|=)+$/,"")).path
 url_root=URI(Node['baseurl']).scheme+"://"+URI(Node['baseurl']).host
 if url[url_root] #url передан в виде <схема>://<логин>:<пароль>@<хост>:<порт>/<URL путь>?<параметры>#<якорь>. Можно ничего не делать
  str=url
 elsif url[0]=="/" #url передан в виде /<URL путь>?<параметры>#<якорь> - путь относительно корня сайта
  str=url_root+url
 else #url передан в виде <URL путь>?<параметры>#<якорь> - путь относительно текущей папки (currpath)
  str=url_root+url_currpath+"/"+url
 end
 return str
end #reconstructurl url


###########################################################################################
# парсинг таблицы со свойствами товара, возвращает двумерный массив
###########################################################################################
def parsetable page
 html=page.clone
 parameters=[]
 if Node.has_key?('good_fieldstable')
  Node['good_fieldstable'].keys.each do |fieldname|
   tableidentifyer=Node['good_fieldstable'][fieldname]#['table_block']
   deletepatterns=[]
   Node['good_fieldstable'][fieldname].keys.each do |fieldproperty|
    if Regexp.new("^delete").match(fieldproperty)
     deletepatterns << Node['good_fieldstable'][fieldname][fieldproperty]['pattern']
    end
   end #Node['good_fields'][fieldname].keys.each do |fieldproperty|
   html.search(tableidentifyer['table_block']).each do |table|
    table.css('tr').each do |row|
     param=[]
     paramtext=""
     cells=[]
     cells << row.css('th')
     cells << row.css('td')
     cells.each do |cell|
      celltext=cell.text.cleareols.removedups.strip
      deletepatterns.each do |deletepattern|
       celltext=celltext.gsub(Regexp.new(deletepattern),"")
      end #deletepatterns.each do |deletepattern|
      if param.size==0
       param << celltext
      else
       paramtext+=celltext+", " if celltext.size>0
      end
     end
     param << paramtext.gsub(/,\s$/,"").cleareols.gsub(/\t/,"")
     parameters << param if ((param.size==2) && (!param[0].to_s.empty?) && (!param[1].to_s.empty?))
    end
    break
   end
  end
 end
 return parameters
end






###########################################################################################
# получитьСтраницу с сервера
###########################################################################################
def getpage url
 page=nil
 loop do
  sleep($timewait)
  agent = Mechanize.new do |browser|
   browser.user_agent_alias = "Linux Firefox"
   #browser.set_proxy '66.35.68.146',8089
   browser.follow_meta_refresh = true
   browser.history.max_size = 1
  end
  begin
   page=agent.get(url)
   break
  rescue Mechanize::ResponseCodeError => ex
   if $timewait<=Maxtimewait
    puts "Ошибка #{ex.response_code} доступа к ".red+"#{url}".white+" - Увеличим задержку до #{$timewait}".red
    $timewait*=2
    redo
   else
    puts "Ошибка #{ex.response_code} доступа к ".red+"#{url}".white+" - Отказаться от попыток? (y/n)".red
    $timewait=1
    break
   end
  rescue Exception => e
   puts "Ошибка #{e} доступа к ".red+"#{url}".white+" - Увеличим задержку до #{$timewait}".red
   $timewait*=2
   if $timewait>Maxtimewait
    $timewait=1
    break
   end
   redo
  end
 end #loop do
 if $timewait>1
  $timewait/=2
 end
 return page
end

###########################################################################################
# парсинг страницы с товаром
###########################################################################################
def parsegood goodlink
 if $goodfound>0
  $goodfound-=1
  puts "Пропущен парсинг страницы с товаром: #{goodlink}".gray+" Ещё осталось пропустить #{$goodfound} страниц с товаром"
  return
 end
 goodBlockIdentifyer=""
 goodBlockIdentifyer=Node['goodblock']

 if goodlink.class.to_s["String"]
  page=getpage goodlink
  if page==nil
   return
  end
 else
  page=goodlink.clone
  goodlink=page.inspect.cleaneols.gsub(/^.+URL:/,"").gsub(/>\}.*$/,"")
 end
 puts "Парсинг страницы с товаром: #{goodlink}".magenta #+", #{page.inspect.cleaneols.gsub(/^.+URL:/,"").gsub(/>\}.*$/,"")}".white
 page.search(goodBlockIdentifyer).each do |inDiv|
  ########################################################### разбор предопределённых полей #######################################################
  somewritten=false
  Node['good_fields'].keys.each do |fieldname|
   fieldblocks=[]
   deletepatterns=[]
   presentas="inner_html"
   Node['good_fields'][fieldname].keys.each do |fieldproperty|
    if Regexp.new("^field_block").match(fieldproperty)
     Node['good_fields'][fieldname].each do |block|
      fieldblocks << block #Node['good_fields'][fieldname][fieldproperty]
     end
    end
    if Regexp.new("^presentas$").match(fieldproperty)
     presentas=Node['good_fields'][fieldname][fieldproperty]
    end
    if Regexp.new("^delete").match(fieldproperty)
     deletepatterns << Node['good_fields'][fieldname][fieldproperty]['pattern']
    end
   end #Node['good_fields'][fieldname].keys.each do |fieldproperty|
   mask=""
   fieldblocks.each do |fieldblock|
    mask=fieldblock[1] if fieldblock[0] =~ /^field_mask$/
   end
   fieldblocks.each do |fieldblock|
    next unless fieldblock[0] =~ /^field_block$/
    inDiv.search(fieldblock[1]).each do |info|
     blocktext= (presentas=="text") ? info.text : (presentas=="") ? info.to_s : info.inner_html.to_s
     blocktext=blocktext.cleaneols.encode('UTF-8').strip
     deletepatterns.each do |deletepattern|
      blocktext=blocktext.gsub(Regexp.new(deletepattern),"")
     end #deletepatterns.each do |deletepattern|
     if fieldname=="image"
      if checkurl(blocktext)
       blocktext=reconstructurl blocktext
      else
       blocktext=""
      end
     end
     next if blocktext.empty?
     unless mask.empty?
      next unless blocktext =~ Regexp.new(mask)
     end
     puts "<#{fieldname}>#{blocktext}</#{fieldname}>".yellow
     $outputfilegoods.write "<#{fieldname}>#{blocktext}</#{fieldname}>"
     somewritten=true
    end #inDiv.search(fieldblock).each do |info|
   end
  end #Node['good_fields'].keys.each do |fieldname|
  #################################### Разбор с помощью css ###############################################################
  if Node.has_key?('good_fieldscss')
   Node['good_fieldscss'].each do |cssblock|
    inDiv.search(cssblock[1]['css_block']).each do |row|
     innerhtml=row.inner_html.encode('UTF-8').cleaneols.removedups.gsub(/<[^>]*>\s*/,":").gsub(/(:{1,}\s*){2,}/,":").gsub(/^,+/,"").gsub("(","").gsub(")","").strip.gsub(/^:+/,"")
     deletepatterns=[]
     cssblock[1].keys.each do |cssproperty|
      if Regexp.new("^delete").match(cssproperty)
       deletepatterns << cssname[1][cssproperty]['pattern']
      end
     end #cssname[1].keys.each do |cssproperty|
     deletepatterns.each do |todelete|
      innerhtml=innerhtml.gsub(Regexp.new(todelete),"")
     end
     if cssblock[1].has_key? 'awaitingfields'
      fieldsarray=innerhtml / /:/
      opened=false
      closed=false
      fieldname=""
      someinwritten=false
      fieldsarray.each do |elem|
       teststr=elem.gsub(",","").strip.gsub(Regexp.new(/^\//),"").removebrakets.gsub(Regexp.new(/\/$/),"").gsub(Regexp.new(/\\/),"").gsub(Regexp.new(/(\?|\.)/),"").encode('UTF-8')
       next if teststr.empty?
       if cssblock[1]['awaitingfields'].to_s.encode('UTF-8').match(teststr)!=nil
        if ((opened) && (!closed))
         print "</#{fieldname}>\n".yellow
         $outputfilegoods.write "</#{fieldname}>"
         someinwritten=false
         opened=false
         closed=true
        end
        fieldname=elem
        next if elem.gsub(/(\.|,|:|\-|=|\?)*/,"").cleaneols.strip.empty?
        print "<#{fieldname}>".yellow
        $outputfilegoods.write "<#{fieldname}>"
        opened=true
        closed=false
       else
        if opened
         print "#{someinwritten ? ',':''}#{elem}".yellow
         $outputfilegoods.write "#{someinwritten ? ',':''}#{elem}"
         someinwritten=true
        end #if opened
       end #if Node['good_fieldscss']['awaitingfields'].match elem.gsub(",","")
      end #fieldsarray.each do |elem|
      if fieldname!=""
       print "</#{fieldname}>\n".yellow
       $outputfilegoods.write "</#{fieldname}>"
       someinwritten=false
       somewritten=true
       opened=false
       closed=true
      end #if fieldname!=""
     end #if cssname[1].has_key? 'awaitingfields'
    end #inDiv.search(cssname[1]['css_block']).each do |row|
   end #Node['good_fieldscss'].each do |cssname|
  end #if Node.has_key? 'good_fieldscss'
  ##################################################### Разбор с помощью table ###########################
  if Node.has_key? 'good_fieldstable'
   parsetable(inDiv).each do |param|
    puts "<#{param[0]}>#{param[1]}</#{param[0]}>".yellow
    $outputfilegoods.write "<#{param[0]}>#{param[1]}</#{param[0]}>"
    somewritten=true
   end
  end
  $outputfilegoods.write "<href>#{goodlink}</href>\r\n" if somewritten
 end #page.search(goodBlockIdentifyer).each do |inDiv|
end #parsegood goodlink

##################################################### тест конфигурации ###################################
def testNode node
 pattern=""
 node.keys.each do |keyname|
  if keyname=="pattern"
   pattern=Regexp.new(node[keyname])
  elsif keyname=="test"
   test=node[keyname]
   if (pattern.match test)
   else
    puts "#{pattern} == #{test} ?".red
   end
  end
  if node[keyname].is_a?(Hash)
   testNode node[keyname]
  end
 end
end #testNode node

####################################################### постраничный прогон по сайту #######################
def kraule url
 puts "Начали прогон по сайту со страницы #{url}".magenta
 querylinks=[]
 querylinks << [0, reconstructurl(url)]
 loop do
  pointer=""
  querylinks.size.times do |n|
   if querylinks[n][0]==0
    pointer=n
    break
   end
  end
  if pointer==""
   puts "Закончен разбор сайта, неисследованных ссылок нет".white
   break
  end
  pagereaded=false
  page=getpage querylinks[pointer][1]
  if page==nil
   querylinks[pointer][0]=-1
   next
  end
  Node['goodpagelinks'].each do |pagelinkpattern|
   if Regexp.new(pagelinkpattern[1]['pattern']).match querylinks[pointer][1]
    if checkurl querylinks[pointer][1]
     goodlink=reconstructurl querylinks[pointer][1]
     if !$goodlinks.include? goodlink  #Все ссылки проверяем только один раз.
      puts "+".white+"+      Товар: ".green+"#{goodlink}".white
      $goodlinks << goodlink
      added=true
      parsegood page
     end
    else
     #next
    end
   end
  end
  puts "Проверка ссылок на странице ".cyan+"#{querylinks[pointer][1]}".white
  page.links_with().each do |link|
   next if link.href==nil
   next if link.href.to_s.size<=1
   added=false
   Node['sublinks'].each do |sublinkpattern|
    if Regexp.new(sublinkpattern[1]['pattern']).match link.href
     newlink=reconstructurl link.href, querylinks[pointer][1]
     if ((!querylinks.include?([0, newlink])) && (!querylinks.include?([1, newlink])))
      puts "+ подстраница: ".green+"#{newlink}".white
      added=true
      querylinks << [0, newlink]
     end
    end
   end
   Node['goodpagelinks'].each do |pagelinkpattern|
    if Regexp.new(pagelinkpattern[1]['pattern']).match link.href
     goodlink=reconstructurl link.href, querylinks[pointer][1]
     if !$goodlinks.include? goodlink  #Все ссылки проверяем только один раз.
      puts "+       Товар: ".green+"#{goodlink}".white
      $goodlinks << goodlink
      added=true
      parsegood goodlink
     end
    end
   end
  end
  querylinks[pointer][0]=1 #Исследовано
  puts "Исследована страница ".green+"(#{pointer} из #{querylinks.size})".yellow+"#{querylinks[pointer][1]}".white
 end #loop in querylinks
end #kraule

###########################################################################################
#                                                                                         #
#                                   ОСНОВНАЯ ПРОГРАММА                                    #
#                                                                                         #
###########################################################################################

settingsxml=ARGV[0]

exit if settingsxml.to_s.empty?
puts "#{settingsxml}".red
parser=""
begin
 parser=Psych.parse(File.read(settingsxml)).to_ruby
rescue Psych::SyntaxError => ex
 ex.file    # => 'file.txt'
 ex.message # => "(file.txt): found character that cannot start any token"
 puts "#{ex.file} #{ex.message}"
end
if parser['settings'].size>0
 Node=parser['settings']
end

$readedlinks=[]
$goodlinks=[]
$timewait=0.5
Maxtimewait=2
filewithgoods="#{Node['name']}.txt"
$goodfound=0
if File.exist?(filewithgoods) #.gsub!(/\r\n?/, "")
 File.open(filewithgoods).read.each_line do |line|
  $goodfound+=1
 end
end
puts "Уже найдено #{$goodfound} товаров."
$outputfilegoods=File.open(filewithgoods,'a')
testNode Node

if (Node['testing']['workmode']=="test")
 $goodfound=-1
 Node['testing'].keys.each do |testpage|
  next unless testpage =~ /^testpage/
  if checkurl Node['testing'][testpage]
   parsegood reconstructurl Node['testing'][testpage]
  end
 end
else
 kraule Node['baseurl']
end