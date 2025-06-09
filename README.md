# laba

## <p align="center"><b>МОДУЛЬ 1</b></p>

 Задание: 
 Необходимо разработать и настроить инфраструктуру информационно коммуникационной системы согласно предложенной топологии (см. Рисунок 1). Задание включает базовую настройку устройств: 
- присвоение имен устройствам, 
- расчет IP-адресации, 
- настройку коммутации и маршрутизации.

 В ходе проектирования и настройки сетевой инфраструктуры следует вести отчет о своих действиях, включая таблицы и схемы, предусмотренные в задании. Итоговый отчет должен содержать одну таблицу и пять отчетов о ходе работы. Итоговый отчет по окончании работы следует сохранить на диске рабочего места

<p align="center">
  <img src="images/module1/2. топология сети.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/1. Таблица IP-адресов.png" width="600" />
</p>

<p align="center"><b>Чтобы зайти на стенд для 1 модуля.</b></p>
 
<p align="center"><b>User name: m1</b></p>
<p align="center"><b>Password: modul1</b></p>

Перед включением виртуалок Настроем вланы. По заданию HQ-SRV в 100 влане, а  HQ-CLI в 200
> **Примечание:**
> Основные сведения о настройке коммутатора и выбора реализации разделения на VLAN занесите в отчёт

<p align="center">
  <img src="images/module1/4. vlan.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/5. vlan.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/6. vlan.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/7. vlan.png" width="600" />
</p>

**ISP преднастроена, но включать ее надо**

<p align="center">
  <img src="images/module1/8. таблица адресации.png" width="600" />
</p>


### <p align="center"><b>Сетевая связность - между HQ и BRANCH</b></p>
> **Примечание:**
> Сведения об адресах занесите в отчёт, в качестве примера используйте Таблицу 3

 <p align="center"><b>*HQ-RTR*</b></p>

Задаём сразу FQDN - выбор имени домена произвольный:

<p align="center">
  <img src="images/module1/9. сетевая связность.png" width="600" />
</p>

По такой же аналогии настройте остальные имена

Чтобы настроить адресацию переходим:

<p align="center">
  <img src="images/module1/10..png" width="600" />
</p>

Заодно настроим GRE туннель

<p align="center">
  <img src="images/module1/11..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/12..png" width="600" />
</p>

Включаем пересылку пакетов между портами (интерфейсами)

<p align="center">
  <img src="images/module1/13..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/14..png" width="600" />
</p>

Применяем: 

***sysctl -p***

Прокинем PAT так, как по приколу тачки, что подключены к роутеру пинговать инет не будут.

<p align="center">
  <img src="images/module1/15..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/16. nftables.png" width="600" />
</p>

Обязательно добавим в автозагрузку и активируем

<p align="center">
  <img src="images/module1/17..png" width="600" />
</p>

Туннель мы допустим подняли, но чтобы пакеты через него пошли, нужна маршрутизация.
> **Примечание:**
> Сведения о настройке и защите протокола(ospf) занесите в отчёт

Установим frr.

<p align="center">
  <img src="images/module1/18..png" width="600" />
</p>

> **РЕКОМЕНДАЦИЯ:**
> ПОКА FRR СКАЧИВАЕТСЯ ПЕРЕХОДИМ К НАСТРОЙКЕ BR-RTR

В файле /etc/frr/daemons - включим поддержку OSPFv2 (IPv4)

<p align="center">
  <img src="images/module1/19..png" width="600" />
</p>

Не забываем перезапускать, чтобы изменения вступили в силу

<p align="center">
  <img src="images/module1/20..png" width="600" />
</p>

Переходим к настройке frr (ospf)

<p align="center">
  <img src="images/module1/21..png" width="600" />
</p>

Поставим пароль на frr

<p align="center">
  <img src="images/module1/22..png" width="600" />
</p>

Не забываем перезапустить

<p align="center">
  <img src="images/module1/23..png" width="600" />
</p>

И добавить в автозагрузку

<p align="center">
  <img src="images/module1/24..png" width="600" />
</p>


 <p align="center"><b>*BR-RTR*</b></p>

Произведем те же манипуляции

<p align="center">
  <img src="images/module1/25..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/26..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/27..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/28..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/29..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/30..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/31..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/32..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/33..png" width="600" />
</p>

> **РЕКОМЕНДАЦИЯ:**
> ПОКА FRR СКАЧИВАЕТСЯ ДОДЕЛЫВАЕМ FRR НА HQ-RTR

<p align="center">
  <img src="images/module1/34..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/35..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/36..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/37..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/38..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/39..png" width="600" />
</p>

Ура сетевая связность у между hq и br настроена

Для проверки пингуем с br-rtr:

***ping 192.168.100.1***

> **РЕКОМЕНДАЦИЯ:**
> сразу на HQ-RTR скачаем: apt update && apt install –y isc-dhcp-server


<p align="center"><b>*HQ-SRV*</b></p>

Задаем имя:  
> **ВНИМАНИЕ:**
> Нужно обновить изображение

<p align="center">
  <img src="images/module1/43..png" width="600" />
</p>

Прокинем инет:

<p align="center">
  <img src="images/module1/40. hq-srv.png" width="600" />
</p>

Перезапускаем сервис:

***Systemctl restart networking***

Проверяем:

<p align="center">
  <img src="images/module1/41..png" width="600" />
</p>


<p align="center"><b>*BR-SRV*</b></p>

<p align="center">
  <img src="images/module1/43..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/42. br-srv.png" width="600" />
</p>

Перезапускаем сервис:

***Systemctl restart networking***

Проверяем:

<p align="center">
  <img src="images/module1/41..png" width="600" />
</p>

> **РЕКОМЕНДАЦИЯ:**
> сразу скачиваем на HQ-SRV: apt update && apt install -y dnsmasq


### <p align="center"><b>Создание локальных учетных записей</b></p>

<p align="center"><b>Создайте пользователя sshuser на серверах</b></p>

<p align="center"><b>*HQ-SRV и BR-SRV*</b></p>

<p align="center">
  <img src="images/module1/44. sshuser.png" width="600" />
</p>

Пользователь sshuser должен иметь возможность запускать sudo без дополнительной аутентификации.

В дебиане нету судо поэтому скачаем:

<p align="center">
  <img src="images/module1/45..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/46..png" width="600" />
</p>

НА BR-SRV СДЕЛАЙТЕ ТОЖЕ САМОЕ


<p align="center"><b>Создайте пользователя net_admin на маршрутизаторах</b></p>

<p align="center"><b>*HQ-RTR и BR-RTR*</b></p>

<p align="center">
  <img src="images/module1/47. net_admin.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/48..png" width="600" />
</p>

В дебиане нет sudo поэтому скачаем

<p align="center">
  <img src="images/module1/49..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/50..png" width="600" />
</p>

СДЕЛАЙТЕ ТОЖЕ САМОЕ НА BR-RTR


### <p align="center"><b>Настройка безопасного удаленного доступа на серверах HQ-SRV и BR-SRV:</b></p>

- Для подключения используйте порт 2024 
- Разрешите подключения только пользователю sshuser ● Ограничьте количество попыток входа до двух 
- Настройте баннер «Authorized access only»

<p align="center"><b>*HQ-SRV и BR-SRV*</b></p>

<p align="center">
  <img src="images/module1/51. ssh.png" width="600" />
</p>

Редактируем файл /etc/ssh/sshd_config:

<p align="center">
  <img src="images/module1/52..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/53..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/54..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/55..png" width="600" />
</p>

ДУБЛИРУЕМ ТОЖЕ САМОЕ НА BR-SRV


### <p align="center"><b>Установим и настроим DHCP-сервер</b></p>

и зарезервируем адрес для HQ-SRV, чтобы потом на всех остальных оконечных устройствах задавая адреса сразу создавать пользователей

<p align="center"><b>*HQ-RTR:*</b></p>

Скачаем: ***apt install –y isc-dhcp-server***

Первым делом нам необходимо указать, что наш DHCP сервер должен принимать запросы только с ens20 интерфейса.

<p align="center">
  <img src="images/module1/56. dhcp.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/57..png" width="600" />
</p>

Настройка протокола динамической конфигурации хостов. 

- Настройте нужную подсеть 
- Для офиса HQ в качестве сервера DHCP выступает маршрутизатор HQ-RTR. 
- Клиентом является машина HQ-CLI. 
- Исключите из выдачи адрес маршрутизатора 
- Адрес шлюза по умолчанию – адрес маршрутизатора HQ-RTR. 
- Адрес DNS-сервера для машины HQ-CLI – адрес сервера HQ-SRV. 
- DNS-суффикс для офисов HQ – au-team.irpo 
- Сведения о настройке протокола занесите в отчёт

<p align="center">
  <img src="images/module1/58. dhcp.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/59..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/60..png" width="600" />
</p>

> **Примечание:**
> Сведения о настройке протокола занесите в отчёт


### <p align="center"><b>Настройка DNS для офисов HQ и BR.</b></p>

- Основной DNS-сервер реализован на HQ-SRV. 
- Сервер должен обеспечивать разрешение имён в сетевые адреса устройств и обратно в соответствии с таблицей 2 
- В качестве DNS сервера пересылки используйте любой общедоступный DNS сервер

Нам необходимо настроить DNS сервер. Будем использовать dnsmasq.

<p align="center"><b>*HQ-SRV*</b></p>

<p align="center">
  <img src="images/module1/61. dns.png" width="600" />
</p>

<p align="center">
  <img src="images/module1/62..png" width="600" />
</p>

<p align="center">
  <img src="images/module1/63..png" width="600" />
</p>

Теперь открываем скрипт-инициализации сервиса dnsmasq

<p align="center">
  <img src="images/module1/64..png" width="600" />
</p>

ищем строчку DNSMASQ_OPTS

<p align="center">
  <img src="images/module1/65.png" width="600" />
</p>

Убираем оттуда –local-service

<p align="center">
  <img src="images/module1/66..png" width="600" />
</p>

Перезагружаем службу dnsmasq:

***systemctl restart dnsmasq***

После настройки dns-сервера прописываем всем машинам в /etc/resolv.conf:

***nameserver 192.168.100.2***

<p align="center">
  <img src="images/module1/67. таблица доменных имен.png" width="600" />
</p>


### <p align="center"><b>Настройте часовой пояс на всех устройствах, согласно месту проведения экзамена.</b></p>

<p align="center"><b>*HQ-SRV, HQ-CLI, BR-SRV*</b></p>

Проверяем какой часовой пояс установлен:

***timedatectl status***

<p align="center">
  <img src="images/module1/68. часовой пояс.png" width="600" />
</p>

Если отличается, то устанавливаем:

***timedatectl set-timezone Asia/Yekaterinburg***



## <p align="center"><b>МОДУЛЬ 2</b></p>

<p align="center"><b>Чтобы зайти на стенд для 2-3 модуля.</b></p>
 
<p align="center"><b>User name: m2</b></p>
<p align="center"><b>Password: modul2</b></p>

### <p align="center"><b>Настройте доменный контроллер Samba на машине BR-SRV.</b></p>

**<p align="center"><b>(СДЕЛАТЬ SNAPSHOT BR-SRV)</b></p>**

- Создайте 5 пользователей для офиса HQ: имена пользователей формата user№.hq. Создайте группу hq, введите в эту группу созданных пользователей 
- Введите в домен машину HQ-CLI 
- Пользователи группы hq имеют право аутентифицироваться на клиентском ПК 
- Пользователи группы hq должны иметь возможность повышать привилегии для выполнения ограниченного набора команд: cat, grep, id. Запускать другие команды с повышенными привилегиями пользователи группы не имеют права 
- Выполните импорт пользователей из файла users.csv. Файл будет располагаться на виртуальной машине BR-SRV в папке /opt

<p align="center"><b>*BR-SRV*</b></p>

> **Обязательно:**
> Временно заменяем в /etc/resolv.conf 192.168.100.2 на  10.0.1.4, чтобы samba быстрее скачивалось

Переходим к настройкам самого контроллера домена на BR-SRV

<p align="center">
  <img src="images/module2/1.samba.png" width="600" />
</p>

> **РЕКОМЕНДАЦИЯ:**
> НА CLI: apt-get update && apt-get remove -y alterator-datetime && apt-get install -y task-auth-ad-sssd && apt-get install -y admc
> НА HQ-SRV: apt update && apt install mdadm -y
> НА CLI: apt-get install -y openssh-server && systemctl restart sshd.

Появится синее окно, не пугайтесь, так и должно быть. В первом окне вводим имя домена au-team.irpo, а во втором — имя нашего сервера hq-srv

Удаляем докер:

***apt remove docker.io -y && ip link delete docker0;***

- Проверяем что установлено имя в формате FQDN;  
- Задаём domainname;  
- Очищаем конфигурацию samba;  
- Разворачиваем контроллер домена Active Directory на базе SambaDC с Dnsmasq в качестве DNS

<p align="center">
  <img src="images/module2/2.png" width="600" />
</p>

<p align="center">
  <img src="images/module2/3.png" width="600" />
</p>

Подготовка домена: Samba-tool --realm=au-team.irpo --domain=au-team –adminpass=”PAssw0rd” --dnsbackend=SAMBA_INTERNAL --option=”dns forwrder=192.168.100.2” --server-role=dc

ВЫ МОЖЕТЕ НАПИСАТЬ ТОЛЬКО «Samba-tool domain provision», А ОСТАЛЬНОЕ ОНО СПРОСИТ САМО

<p align="center">
  <img src="images/module2/4.png" width="600" />
</p>

Как видим че то не так, надо перезапустить машинку:

***reboot***

Вводим все заново  
Проверяем:

<p align="center">
  <img src="images/module2/5.png" width="600" />
</p>

Ничего не показывает, надо перезапустить машину, снова проверяем:

<p align="center">
  <img src="images/module2/6.png" width="600" />
</p>

> **Обязательно:**
> ВВОДИМ МАШИНУ обратно В ДОМЕН:
>  
> nano /etc/resolv.conf – nameserver 192.168.100.2

> **РЕКОМЕНДАЦИЯ:**
> НА BR-SRV здесь же скачиваем: apt install ansible -y
> 
> НА HQ-SRV скачиваем: apt install nfs-kernel-server -y

<p align="center"><b>На клиента ставим необходимые пакеты</b></p>

<p align="center"><b>*CLI*</b></p>

При установке пакета task-auth-ad-sssd у вас возникнет ошибка, связанная с конфликтом с пакетом alterator-datetime, его необходимо удалить:

***apt-get update && apt-get remove -y alterator-datetime***

После пропишем инсталл:

***apt-get install -y task-auth-ad-sssd***

Переходим к редактированию временного соединения и в качестве DNS-сервера прописываем адрес HQ-SRV, а также указываем поисковый домен:

<p align="center">
  <img src="images/module2/7.png" width="600" />
</p>

Переходим в Центр управления системой, на вкладке Пользователи выбираем Аутентификация

<p align="center">
  <img src="images/module2/8.png" width="600" />
</p>

<p align="center">
  <img src="images/module2/9.png" width="600" />
</p>

<p align="center">
  <img src="images/module2/10.png" width="600" />
</p>

Вводим пароль администратора домена:

<p align="center">
  <img src="images/module2/11.png" width="600" />
</p>

Нажимаем ОК и перезагружаем систему:

<p align="center">
  <img src="images/module2/12.png" width="600" />
</p>

> **РЕКОМЕНДАЦИЯ:** 
> НА BR-SRV скачиваем: apt install -y docker.io docker-compose  
> НА HQ-SRV скачиваем: apt install -y apache* -y

В качестве проверки после перезагрузки можно выполнить аутентификацию от имени доменного пользователя Administrator:

<p align="center">
  <img src="images/module2/13.png" width="600" />
</p>

Организуем отслеживание подключения к домену: CLI: На клиенте с граф. интерфейсом установим Модуль удаленного управления базой данных конфигурации (ADMC) • Установим пакет admc:

***apt-get install -y admc***

Для использования ADMC необходимо предварительно получить ключ Kerberos для администратора домена. Получить ключ Kerberos можно, например, выполнив следующую команду, из под обычного пользователя:

***kinit Administrator***

ADMC запускается из меню запуска приложений: пункт «Системные» → ADMC или из командной строки (команда admc).

_____________________________________________________________________________________
Если admc долго не может запуститься(не выдает ошибок, но не запускается), то внесите изменения в файл /etc/krb5.conf

<p align="center">
  <img src="images/module2/14.png" width="600" />
</p>
_____________________________________________________________________________________

На вкладке «Компьютеры» в графическом режиме удобно отслеживать подключение к домену.

Создаем пять юзеров:

<p align="center">
  <img src="images/module2/15.png" width="600" />
</p>

<p align="center">
  <img src="images/module2/16.png" width="600" />
</p>

<p align="center"><b>Создаем группу hq и в нее добавляем раннее созданных пользователей</b></p>

Пользователи группы hq должны иметь возможность повышать привилегии для выполнения ограниченного набора команд: cat, grep, id. Запускать другие команды с повышенными привилегиями пользователи группы не имеют права

<p align="center"><b>*CLI*</b></p>

Настройте файл /etc/sudoers на рабочей станции Linux, как описано в предыдущем ответе, используя синтаксис для доменных групп:  
%hq ALL=(ALL) NOPASSWD: /bin/cat, /bin/grep, /usr/bin/id

> **РЕКОМЕНДАЦИЯ:**
> НА BR-SRV скачиваем: apt install –y mariadb-*  
> НА HQ-SRV скачиваем: apt install -y php php8.2 php-curl php-zip php-xml libapache2-mod-php php-mysql php-mbstring php-gd php-intl php-soap -y
