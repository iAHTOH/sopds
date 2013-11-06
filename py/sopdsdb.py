#!/usr/bin/python3
# -*- coding: utf-8 -*-

import os
import sys
import mysql.connector
from mysql.connector import errorcode

##########################################################################
# Наименования таблиц БД
#
DB_PREFIX=""
TBL_BOOKS=DB_PREFIX+"books"
TBL_TAGS=DB_PREFIX+"tags"
TBL_BTAGS=DB_PREFIX+"btags"
TBL_CATALOGS=DB_PREFIX+"catalogs"

###########################################################################
# Класс доступа к  MYSQL
#

class opdsDatabase:
  def __init__(self,iname,iuser,ipass,ihost,iroot_lib):
    self.db_name=iname
    self.db_user=iuser
    self.db_pass=ipass
    self.db_host=ihost
    self.errcode=0
    self.err=""
    self.isopen=False
    self.next_page=False
    self.root_lib=iroot_lib

  def openDB(self):
    if not self.isopen:
      try:
         # buffered=true сделано для того чтобы избежать выборки fetchall при поиске книг и тэгов
         self.cnx = mysql.connector.connect(user=self.db_user, password=self.db_pass, host=self.db_host, database=self.db_name, buffered=True)
      except mysql.connector.Error as err:
         if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            self.err="Something is wrong with your user name or password"
            self.errcode=1
         elif err.errno == errorcode.ER_BAD_DB_ERROR:
            self.err="Database does not exists"
            self.errcode=2
         else:
            self.err=err
            self.errcode=3
      else:
         self.isopen=True
    else:
      self.errcode=4
      self.err="Error open database. Database Already open."

  def closeDB(self):
    if self.isopen:
      self.cnx.close()
      self.isopen=False
    else:
      self.errcode=5
      self.err="Attempt to close not opened database."

  def printDBerr(self):
    if self.errcode==0:
       print("No Database Error found.")
    else:
       print("Error Code =",self.errcode,". Error Message:",self.err)

  def clearDBerr(self):
    self.err=""
    self.errcode=0

  def findtag(self,tag):
    sql_findtag=("select tag_id from "+TBL_TAGS+" where tag='"+tag+"'")
    cursor=self.cnx.cursor()
    cursor.execute(sql_findtag)
    row=cursor.fetchone()
    if row==None:
       tag_id=0
    else:
       tag_id=row[0]
    cursor.close()
    return tag_id

  def findbook(self, name, path):
    sql_findbook=("select book_id from "+TBL_BOOKS+" where filename=%s and fullpath=%s")
    data_findbook=(name,path)
    cursor=self.cnx.cursor()
    cursor.execute(sql_findbook,data_findbook)
    row=cursor.fetchone()
    if row==None:
       book_id=0
    else:
       book_id=row[0]
    cursor.close()
    return book_id

  def findbtag(self, book_id, tag_id):
    sql_findbtag=("select book_id from "+TBL_BTAGS+" where book_id=%s and tag_id=%s")
    data_findbtag=(book_id,tag_id)
    cursor=self.cnx.cursor()
    cursor.execute(sql_findbtag,data_findbtag)
    row=cursor.fetchone()
    result=(row!=None)
    cursor.close()
    return result
 
  def addbook(self, name, path, cat_id, exten, size=0):
    book_id=self.findbook(name,path)
    if book_id!=0:
       return book_id
    format=exten[1:]
    sql_addbook=("insert into "+TBL_BOOKS+"(filename,fullpath,cat_id,filesize,format) VALUES(%s, %s, %s, %s, %s)")
    data_addbook=(name,path,cat_id,size,format)
    cursor=self.cnx.cursor()
    cursor.execute(sql_addbook,data_addbook)
    book_id=cursor.lastrowid
    self.cnx.commit()
    cursor.close()
    return book_id
    
  def addtag(self, tag, tag_type=0):
    tag_id=self.findtag(tag)
    if tag_id!=0:
       return tag_id
    sql_addtag=("insert into "+TBL_TAGS+"(tag,tag_type) VALUES(%s,%s)")
    data_addtag=(tag,tag_type)
    cursor=self.cnx.cursor()
    cursor.execute(sql_addtag,data_addtag)
    tag_id=cursor.lastrowid
    self.cnx.commit()
    cursor.close()
    return tag_id

  def addbtag(self, book_id, tag_id):
    if not self.findbtag(book_id,tag_id):
       sql_addbtag=("insert into "+TBL_BTAGS+"(book_id,tag_id) VALUES(%s,%s)")
       data_addbtag=(book_id,tag_id)
       cursor=self.cnx.cursor()
       cursor.execute(sql_addbtag,data_addbtag)
       btag_id=cursor.lastrowid
       self.cnx.commit()
       cursor.close()

  def findcat(self, catalog):
    (head,tail)=os.path.split(catalog)
    sql_findcat=("select cat_id from "+TBL_CATALOGS+" where cat_name=%s and full_path=%s")
    data_findcat=(tail,catalog)
    cursor=self.cnx.cursor()
    cursor.execute(sql_findcat,data_findcat)
    row=cursor.fetchone()
    if row==None:
       cat_id=0
    else:
       cat_id=row[0]
    cursor.close()
    return cat_id

  def addcattree(self, catalog):
    cat_id=self.findcat(catalog)
    if cat_id!=0:
       return cat_id 
    if catalog==self.root_lib:
       return 0
    (head,tail)=os.path.split(catalog)
    parent_id=self.addcattree(head)
    sql_addcat=("insert into "+TBL_CATALOGS+"(parent_id,cat_name,full_path) VALUES(%s, %s, %s)")
    data_addcat=(parent_id,tail,catalog)
    cursor=self.cnx.cursor()
    cursor.execute(sql_addcat,data_addcat)
    cat_id=cursor.lastrowid
    self.cnx.commit()
    cursor.close()
    return cat_id

  def getcatinparent(self,parent_id,limit=0,page=0):
    if limit==0:
       limitstr=""
    else:
       limitstr="limit "+str(limit*page)+","+str(limit)
    sql_findcats=("select cat_id,cat_name from "+TBL_CATALOGS+" where parent_id="+str(parent_id)+" order by cat_name "+limitstr)
    cursor=self.cnx.cursor()
    cursor.execute(sql_findcats)
    rows=cursor.fetchall()
    cursor.close
    return rows

  def getbooksincat(self,cat_id,limit=0,page=0):
    if limit==0:
       limitstr=""
    else:
       limitstr="limit "+str(limit*page)+","+str(limit)
    sql_findbooks=("select book_id,filename, fullpath, registerdate from "+TBL_BOOKS+" where cat_id="+str(cat_id)+" order by filename "+limitstr)
    cursor=self.cnx.cursor()
    cursor.execute(sql_findbooks)
    rows=cursor.fetchall()
    cursor.close
    return rows

  def getitemsincat(self,cat_id,limit=0,page=0):
    if limit==0:
       limitstr=""
    else:
       limitstr="limit "+str(limit*page)+","+str(limit)
    sql_finditems=("select SQL_CALC_FOUND_ROWS 1,cat_id,cat_name,full_path,now() from "+TBL_CATALOGS+" where parent_id="+str(cat_id)+" union all "
    "select 2,book_id,filename,fullpath,registerdate from "+TBL_BOOKS+" where cat_id="+str(cat_id)+" order by 1,3 "+limitstr)
    cursor=self.cnx.cursor()
    cursor.execute(sql_finditems)
    rows=cursor.fetchall()
    
    cursor.execute("SELECT FOUND_ROWS()")
    found_rows=cursor.fetchone()
    if found_rows[0]>limit*page+limit:
       self.next_page=True
    else:
       self.next_page=False

    cursor.close
    return rows

  def getbook(self,book_id):
    sql_getbook=("select filename, fullpath, registerdate, format from "+TBL_BOOKS+" where book_id="+str(book_id))
    cursor=self.cnx.cursor()
    cursor.execute(sql_getbook)
    row=cursor.fetchone()
    cursor.close
    (file_name,file_path,reg_date,format)=row
    book_path=os.path.join(file_path, file_name)
    return (file_name,book_path,reg_date,format)

  def __del__(self):
    self.closeDB()

