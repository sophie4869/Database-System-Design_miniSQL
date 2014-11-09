%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sqlcommand.h"
#include "base.h"
#include "API.h"
#include "CatalogManager.h"

//#include "recordmanager.h"
extern "C"{
void yyerror(const char *s);
extern int yylex(void);
extern int yylineno;
extern char* yytext;
extern FILE* yyin;
}
sqlcommand sql;
bool checkLexeme(std::string s);
std::string attrn[32];
int attrp[32];//0:ordinary 1:primary 2:unique
int attrt[32];//0:int 1:char 2:float 
int attrcount=0;
std::string tablen,indexn,attrname;
void prompt();
void reset();
void execute(std::string s);
void attrExist(std::string s);
void printRecordInfo(std::string s, Recordinfo r);
bool checkPrimary(std::string s);
bool exists(std::string s1,std::string s2,std::string s3="");
std::string primaryAttr;

CatalogManager *catalogmanager;
RecordManager *recordmanager;
IndexManager *indexmanager;
BufferManager *buffermanager;
API *api;

%}

%union {char *strVal;char *id;int intVal;float flVal;char *condition;}
%token UNIQUE TABLE SELECT INSERT DROP DELETE INDEX QUIT EXECFILE FROM WHERE CREATE
%token INTO VALUES ON PRIMARY KEY INT CHAR FLOAT ANND
%token UNEXPECTED WHITESPACE
%token <strVal> STRING FILENAME
%token <id> identifier
%token <intVal> intnum
%token <flVal> fnum
%left ANND
%left LE GE NE '>' '<' 
%right '='
%left '+' '-' '*' '/'
%type <condition> where_clause condition
%type <flVal> number
%type <strVal> operation value
%type <id> priattr attrn attrname tablename indexname selectattr



%%





line	: create_table ';'	{
		if(checkLexeme("createtable")){
			execute("createtable");
			sql.getCreateTableInfo();
		}
		reset();
		}
	| create_index	';'	{
		checkLexeme("createindex");
		execute("createindex");
		sql.getCreateIndexInfo();
		reset();
	}
	| select_statement ';'	{
		checkLexeme("select");
		execute("select");
		//sql.getconditions();
		//sql.getSelectInfo();
		//printf("%s\n", sql.getSelectTablen().c_str());
		reset();
	}
	| delete_statement ';'	{
		checkLexeme("delete");
		execute("delete");
		sql.getconditions();
		reset();
	}
	| drop_table ';'	{
		checkLexeme("droptable");
		execute("droptable");
		printf("%s",sql.getTablen().c_str());
		reset();
	}
	| drop_index ';'	{
		checkLexeme("dropindex");
		execute("dropindex");
		printf("%s",sql.getIndexn().c_str());
		reset();
	}
	| insert_statement ';' {
		checkLexeme("insert");
		execute("insert");
		sql.getcolValue();
		reset();
	}
	| EXECFILE FILENAME ';' {
		const char* path=$2;
		FILE *fp=fopen(path,"r");
		if(fp==NULL)	printf("cannot open file %s\n", $2);
		else yyin=fp;
	}
	| QUIT ';'	{
		printf("Bye~\n");
		exit(EXIT_SUCCESS);
	}
	| line QUIT ';'	{
		printf("Bye~\n");
		exit(EXIT_SUCCESS);
	}
	| line create_table ';'	{
		if(checkLexeme("createtable")){
			execute("createtable");
			sql.getCreateTableInfo();
		}
		reset();
	}
	| line create_index ';' {
		checkLexeme("createindex");
		execute("createindex");
		sql.getCreateIndexInfo();
		reset();
	}
	| line select_statement ';' {
		checkLexeme("select");
		execute("select");
		//sql.getconditions();
		//sql.getSelectInfo();
		//printf("%s\n", sql.getSelectTablen().c_str());
		reset();
	}
	| line delete_statement ';'	{
		checkLexeme("delete");
		execute("delete");
		sql.getconditions();
		reset();
	}
	| line insert_statement ';' {
		checkLexeme("insert");
		execute("insert");
		sql.getcolValue();
		reset();
	}
	| line drop_table ';' {
		checkLexeme("droptable");
		execute("droptable");
		printf("%s",sql.getTablen().c_str());
		reset();
	}
	| line drop_index ';' {
		checkLexeme("dropindex");
		execute("dropindex");
		printf("%s",sql.getIndexn().c_str());
		reset();
	}
	| line EXECFILE FILENAME ';' {
		const char* path=$3;
		FILE *fp=fopen(path,"r");
		if(fp==NULL)	printf("cannot open file %s\n", $3);
		else yyin=fp;
	}
	;


create_index	: CREATE INDEX indexname ON tablename '(' attrname ')'
	;

insert_statement	: INSERT INTO tablename VALUES '(' valuelist ')' 
	;

valuelist	: value {sql.setcolValue($1);}
	| valuelist ',' value {sql.setcolValue($3);}
	;

value : STRING {attrt[attrcount++]=strlen($1);$$=$1;}
	//| number {char s[30];sprintf(s, "%f", $1);$$=s;}
	| intnum {attrt[attrcount++]=0;char s[30];sprintf(s, "%d", $1);$$=s;}
	| fnum {attrt[attrcount++]=-1;char s[30];sprintf(s, "%f", $1);$$=s;}
	;

select_statement	: SELECT '*' FROM tablename where_clause	{sql.setSelectInfo("*");}	
	| SELECT attrs FROM tablename where_clause	{;}	
	;
attrs : selectattr
	| attrs ',' selectattr
	;
selectattr	: identifier	{sql.setSelectInfo($1);}
delete_statement	: DELETE FROM tablename where_clause	{;}
	;
where_clause	: WHERE condition	{;}
	|/* empty */ {;}
	;

condition	: attrname operation number	
	{
		char s[30];
		sprintf(s, "%f", $3);
		sql.setconditions(attrname,$2,std::string(s));	
	}
	| attrname operation STRING
		{
			std::string s=$3;
			sql.setconditions(attrname,$2,s);		
		}
	| condition ANND condition	{;}
	;

operation	: GE	{strcpy($$,">=");}
	| LE	{strcpy($$,"<=");}
	| NE	{strcpy($$,"<>");}
	| '<'	{strcpy($$,"<");}
	| '>'	{strcpy($$,">");}
	| '='	{strcpy($$,"=");}
	;
number	: intnum {$$=$1;}
	| fnum {$$=$1;}
	;
tablename	: identifier	{tablen=$1;}
	;

create_table	: CREATE TABLE tablename '(' table_element_list ',' table_constraint ')'
	| CREATE TABLE tablename '(' table_element_list ')'
	;

table_element_list	: table_element
	| table_element_list ',' table_element
	;
table_element	: column_def
	;
column_def	: attrn data_type 
	| attrn data_type column_constraint	
	;
attrn 	: identifier	{
	if(attrcount<32) attrn[attrcount++]=$1;
	else yyerror("Too many attributes!");
}
attrname	: identifier	{attrname=$1 ;}
	;
data_type	: INT	{attrt[attrcount-1]=0;}
	| CHAR '(' intnum ')'	{
		//char* s;
		//int i = $3;
		if($3>255||$3<1)	yyerror("Char is defined too long or too short!");
		else attrt[attrcount-1]=$3;
	}
	| FLOAT	{attrt[attrcount-1]=-1;}
	;
table_constraint	: PRIMARY KEY '(' priattr ')'	{}
	;
priattr	: identifier	{primaryAttr=$1;}
	;
column_constraint	: UNIQUE	{attrp[attrcount-1]=2;}
	;



drop_table	: DROP TABLE tablename{;}
	;	
drop_index	: DROP INDEX indexname{;}
	;
indexname	: identifier	{indexn=$1;}
	;

%%
void yyerror(const char *s)
{
		char c;
		std::string tmp1,tmp2;
		tmp1=s;
		tmp2=yytext;
		if(strcmp(yytext,";")&&strcmp(s,"Unterminated string")) while((c=yylex())!=';');
		if(strcmp(s,"Char is defined too long or too short!"))
       printf("%s near '%s'\n",s,yytext);
       else
       	printf("%s\n",s);
        //if(strcmp(yytext,";")&&strcmp(s,"Unterminated string"))
        //while((c=yylex()!=';')&&c!=EOF);
        sql.clear();
        reset();
        //yyparse();
}
void prompt(){
	printf(">>> ");
}

bool checkLexeme(std::string s){
	if(s=="select"){
		if(!catalogmanager->TableExists(sql.getTablen())) return false;
		std::vector<std::vector<std::string> > v=sql.getconditions();
		std::vector<std::vector<std::string> >::iterator iter;
		for(iter = v.begin(); iter != v.end(); iter++)  {
			std::vector<std::string>::iterator it = (*iter).begin();
			if(!catalogmanager->AttrExists(*it,sql.getTablen())) return false;
		}
		std::vector<std::string> attr=sql.GetSelectInfo();
		std::vector<std::string>::iterator it;
		if(*attr.begin()!="*"){
		for(it = attr.begin(); it != attr.end(); it++)  {
			if(!catalogmanager->AttrExists(*it,sql.getTablen())) return false;
		}
		}
		return true;
	}
	if(s=="delete"){
		if(catalogmanager->TableExists(sql.getTablen())) return false;
		std::vector<std::vector<std::string> > v=sql.getconditions();
		std::vector<std::vector<std::string> >::iterator iter;
		for(iter = v.begin(); iter != v.end(); iter++)  {
			std::vector<std::string>::iterator it = (*iter).begin();
			if(!catalogmanager->AttrExists(*it,sql.getTablen())) return false;
		}
		return true;
	}
	if(s=="insert"){
		if(!catalogmanager->TableExists(sql.getTablen())) return false;
		//std::cout<< "inserted "<<attrcount<<std::endl;
		int c=catalogmanager->AttrCount(tablen);
		if(attrcount!=c) return false;
		//std::vector<int> tablet[32];
		//tablet=cm->getAllAttrType(tablen);
		for(int i=0;i<c;i++){
			if(attrt[i]!=catalogmanager->getAllAttrType(tablen)[i]||(attrt[i]==0&&catalogmanager->getAllAttrType(tablen)[i]==-1)) return false;
		}
		return true;
	}
	if(s=="createtable"){
		if(catalogmanager->TableExists(tablen)) return false;
		if(tablen.length()>64) {
			printf("Table name is too long!\n");
			return false;
		}

		for(int i=0;i<attrcount;i++){
			for(int j=i+1;j<attrcount;j++){
			//printf("i=%d",i);
				if(attrn[i]==attrn[j]){
					printf("Duplicate attribute names '%s'!\n",attrn[i].c_str());
					return false;
	        		}
			}
		}
		if(primaryAttr!="")	if(!checkPrimary(primaryAttr)) return false;
		return true;
	}

	if(s=="createindex"){
		//printf("create index check\n");
		return catalogmanager->TableExists(tablen) && catalogmanager->AttrExists(attrname,tablen) && catalogmanager->IndexExists(indexn);
	}
	

	if(s=="droptable"){
		//check if tablen exists...
		return catalogmanager->TableExists(tablen);
	}
	if(s=="dropindex"){
		//check if indexn exists...
		return catalogmanager->IndexExists(indexn);
	}
	
	return false;
}

// bool exists(std::string s0,std::string s1,std::string s2){
// 	if(s0=="table")	return cm->TableExists(s1);
// 	if(s0=="attr")	return cm->AttrExists(s1,s2);
// 	if(s0=="index")	return cm->IndexExists(s1);
// 	return true;
// }
void execute(std::string s){
	if(s=="select"){
		sql.sqlType=0;
		sql.tablename=tablen;
		//Select_Record()
		printRecordInfo("Select",api->select(sql));
	}
	if(s=="delete"){
		sql.sqlType=1;
		sql.tablename=tablen;
		printRecordInfo("Delete",api->del(sql));
	}
	if(s=="insert"){
		sql.sqlType=2;
		sql.tablename=tablen;
		printRecordInfo("Insert",api->insert(sql));
	}
	if(s=="createtable"){
		//printf("creating...");
		//create tables according to attrn/p/t & tablen
		sql.sqlType=3;
		sql.setCreateTableInfo(tablen,attrn,attrp,attrt);
		printRecordInfo("Create table",api->createTable(sql));
	}
	if(s=="createindex"){
		sql.sqlType=4;
		sql.indexname=indexn;
		sql.setCreateIndexInfo(tablen,attrname);
		printRecordInfo("Create index",api->createIndex(sql));
	}
	if(s=="droptable"){
		//printf("dropping table\n");
		//return failure reason or success message...
		sql.sqlType=5;
		sql.tablename=tablen;
		printRecordInfo("Drop table",api->dropTable(sql));
	}
	if(s=="dropindex"){
		//printf("dropping index\n");
		sql.sqlType=6;
		sql.indexname=indexn;
		printRecordInfo("Drop index",api->dropIndex(sql));
	}

}


bool checkPrimary(std::string s){
	int i;
	for(i = 0;i<attrcount;i++)
		if(attrn[i]==s)	break;
	if(i==attrcount&&attrn[i]!=s)
	{
		printf("Key column '%s' does not exist in table!\n",s.c_str());
		return false;	
	}
	attrp[i]=1;
	return true;
	// automatic index....
}

void printResult(Result res){
	Row row;
	//Result::iterator iter;
	std::vector<Row>::iterator iter;
	for(iter = res.rows.begin(); iter != res.rows.end(); iter++)  {
	printf("|");
	for(std::vector<std::string>::iterator it = (*iter).cols.begin(); it != (*iter).cols.end(); it++)
		printf(" %s\t",(char *)(*it).c_str());
	printf("|\n");
	}
}

void printRecordInfo(std::string s,Recordinfo info){
	if(info.getSucc()){
		printf("%s succeeded!%s\n",s.c_str(),info.getMessage().c_str());
		printResult(info.getRes());
	}
	else{
		printf("%s failed!%s\n",s.c_str(),info.getMessage().c_str());
	}
}
void reset(){
	attrcount=0;
	for(int i = 0;i<32;i++)	
		{
			attrn[i]="";
			attrp[i]=0;
			attrt[i]=0;
		}
	primaryAttr="";
	tablen="";
	indexn="";
	attrname="";
	sql.clear();
	yyparse();
}
int main()
{
	
catalogmanager = new CatalogManager();
recordmanager = new RecordManager();
indexmanager = new IndexManager();
buffermanager = new BufferManager();
api = new API();
	prompt();

	//printResult();
	reset();
    //yyparse ( );
    //delete sql;
	return 0;
} 