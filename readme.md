[Парсер сайтов на Ruby 2.0] (https://github.com/r72cccp/rubyparser "Белевский Сергей. Ruby парсер сайтов с настройками YAML Перейти на страницу проекта")
##Парсер 
####На входе принимает одно значение:
    1. Имя файла yml с настройками. Образец оформления файла настроек - anysiteforexample.ru.settings.yml

####Если параметры не заданы осуществляется выход. 
  Для тестового прогона обязательно наличие файла *.settings.yml в текущем каталоге, откуда запущен парсер.

  На практике парсинг сайта, такой, чтобы тебя не забанили на нём навсегда может идти неделю-две. Тонкий и нежный подход компенсируется надёжным получением требуемой информации.

  В результате работы формируется текстовый файл в текущем каталоге.

####Проблемы и текущие недоработки:
  При перезагрузке компьютера на повторный вход в парсинг может занять продолжительное время. 

  Все исходники здесь: https://github.com/r72cccp/rubyparser.git 

####Там выложены следующие файлы: 
  uniparse.site.rb                  - Рабочий исходник парсера. Работает при вызове из командной строки. Испытано в Linux Server 12.04 Ruby 2.0
  anysiteforexample.ru.settings.yml - Пример файла настроек парсинга 
