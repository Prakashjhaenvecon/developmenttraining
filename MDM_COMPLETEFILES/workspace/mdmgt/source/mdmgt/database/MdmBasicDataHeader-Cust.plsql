-----------------------------------------------------------------------------
--
--  Logical unit: MdmBasicDataHeader
--  Component:    MDMGT
--
--  IFS Developer Studio Template Version 3.0
--
--  Date    Sign    History
--  ------  ------  ---------------------------------------------------------
-----------------------------------------------------------------------------

layer Cust;

-------------------- PUBLIC DECLARATIONS ------------------------------------


-------------------- PRIVATE DECLARATIONS -----------------------------------


-------------------- LU SPECIFIC IMPLEMENTATION METHODS ---------------------

@Override
PROCEDURE Prepare_Insert___ (
   attr_ IN OUT VARCHAR2 )
IS
BEGIN  
   SUPER(attr_);
   Client_SYS.Add_To_Attr('REVISION', 1, attr_);
   Client_SYS.Add_To_Attr('CREATED_BY', fnd_session_api.Get_Fnd_User, attr_);
   Client_SYS.Add_To_Attr('CREATED_DATE', SYSDATE, attr_);   
END Prepare_Insert___;

@Override
PROCEDURE Modify__ (
   info_       OUT    VARCHAR2,
   objid_      IN     VARCHAR2,
   objversion_ IN OUT VARCHAR2,
   attr_       IN OUT VARCHAR2,
   action_     IN     VARCHAR2 )
IS
    status__     VARCHAR2(25);
   CURSOR c1 IS
   select v.state from MDM_BASIC_DATA_HEADER v
 where v.objid = objid_
 and v.objversion = objversion_;
BEGIN
   OPEN c1 ;
    FETCH c1 INTO status__ ;
    CLOSE c1;
    IF status__ = 'Activated' THEN
   Error_SYS.Record_General(lu_name_,'MODIFY:  You can''t Update any Data. Because of Status is '||status__);
    ELSE       
   --Add pre-processing code here
   super(info_, objid_, objversion_, attr_, action_);
   --Add post-processing code here
    END IF;
 END Modify__;
 
FUNCTION C_Get_Next_Rev_No (
   template_id_       IN VARCHAR2) RETURN NUMBER
IS
      rev_no_      NUMBER;
      CURSOR get_data IS
         SELECT MAX(t.REVISION) + 1
         FROM mdm_basic_data_header_tab t
         WHERE TEMPLATE_ID = template_id_;
   BEGIN
      OPEN get_data;
      FETCH get_data INTO rev_no_;
      CLOSE get_data;
      
      RETURN rev_no_;
   
END C_Get_Next_Rev_No;

PROCEDURE Cc_Approval_Process__ (
      new_access_person_ OUT VARCHAR2,
      new_access_group_  OUT VARCHAR2,
      lu_name_           IN VARCHAR2,
      newrec_     IN OUT NOCOPY mdm_basic_data_header_tab%ROWTYPE) 
      
IS
	  info_             VARCHAR2(2000);
      attr_             VARCHAR2(30000);
      objversion_       VARCHAR2(260);
      objid_            VARCHAR2(50);
      step_no_max_      NUMBER;
      doc_class_        VARCHAR2(12);
      doc_no_           VARCHAR2(120);
      doc_sheet_        VARCHAR2(20);
      doc_rev_          VARCHAR2(6);
      objstate_         VARCHAR2(50);
      new_person_id_    VARCHAR2(30000);
      new_group_id_     VARCHAR2(30000);
      conn_desc_        APPROVAL_ROUTING_TAB.CONNECTION_DESCRIPTION%TYPE; -- Bug Id 110267, Changed to have the same type as the correcponding table column.
      sub_con_no_       VARCHAR2(60);
      valuation_no_     VARCHAR2(60);
      key_ref_          VARCHAR2(250);
      profile_id_       VARCHAR2(250);
      
   
      CURSOR object_copy IS
         SELECT line_no, step_no, person_id, description, group_id,security_checkpoint_req
         FROM   approval_template_tab
         WHERE  profile_id = profile_id_;
   BEGIN
   key_ref_ := 'TEMPLATE_ID='||newrec_.TEMPLATE_ID||'^';
   profile_id_ := nvl(newrec_.profile_id,'CAB');
      Approval_Profile_Api.Exist(profile_id_);
   
      SELECT NVL(MAX(step_no), 0) INTO step_no_max_ FROM APPROVAL_ROUTING
         WHERE lu_name = lu_name_
         AND   key_ref = key_ref_;
   
      Object_Connection_SYS.Get_Connection_Description(conn_desc_,lu_name_,key_ref_);
      conn_desc_ := SUBSTR(conn_desc_, 1, 2000);     
      FOR object_ IN object_copy LOOP
         Approval_Routing_API.New__ (info_, objid_, objversion_, attr_, 'PREPARE');
		 
         Client_SYS.Add_To_Attr( 'LU_NAME', lu_name_, attr_ );
         Client_SYS.Add_To_Attr( 'KEY_REF', key_ref_, attr_ );
         Client_SYS.Add_To_Attr( 'CONNECTION_DESCRIPTION', conn_desc_, attr_);
         Client_SYS.Add_To_Attr( 'LINE_NO', object_.line_no, attr_ );
         Client_SYS.Add_To_Attr( 'STEP_NO', (object_.step_no + step_no_max_), attr_ );
         Client_SYS.Add_To_Attr( 'DESCRIPTION', object_.description, attr_ );
         Client_SYS.Add_To_Attr( 'PERSON_ID', object_.person_id, attr_ );
         Client_SYS.Add_To_Attr( 'GROUP_ID', object_.group_id, attr_ );
         IF object_.security_checkpoint_req IS NOT NULL THEN
            Client_SYS.Set_Item_Value('SECURITY_CHECKPOINT_REQ', object_.security_checkpoint_req,  attr_);
         END IF;   
         Approval_Routing_API.New__ (info_, objid_, objversion_, attr_, 'DO');
      END LOOP;
   
      IF (new_person_id_ = ', ') THEN
         new_person_id_ := '';
      ELSIF ( new_group_id_ = ', ') THEN
         new_group_id_ := '' ;
      END IF;
   
      new_access_person_ := Ltrim(new_person_id_, ',');
      new_access_group_  := Ltrim(new_group_id_, ',');
   
      IF (lu_name_ = 'DocIssue') THEN
         DOC_ISSUE_API.Update_Profile_Id__(doc_class_, doc_no_, doc_sheet_, doc_rev_, profile_id_, 'TRUE');
      END IF;
   END Cc_Approval_Process__;
   
PROCEDURE C_Create_New_Revis_Struct(
   template_id_               IN VARCHAR2,
   old_revision_  IN NUMBER )
IS
      attr_          VARCHAR2(2000);
      info_          VARCHAR2(2000);
      objid_         VARCHAR2(2000);
      objversion_    VARCHAR2(2000);
      rec_           MDM_BASIC_DATA_HEADER%ROWTYPE;
      n_rec_         NUMBER;
      temp_revision_ MDM_BASIC_DATA_HEADER_TAB.revision%TYPE;
      last_act_rev_  MDM_BASIC_DATA_HEADER_TAB.revision%TYPE;
      new_revision_  NUMBER;
       
      CURSOR get_pre_rev IS
         SELECT revision
         FROM mdm_basic_data_header_tab
         WHERE Template_id = template_id_
         AND   rowstate = 'Activated';
         
      CURSOR get_Count IS
         SELECT count(*)
         FROM mdm_basic_data_header_tab
         WHERE Template_id = template_id_
         AND   rowstate = 'Activated'; 
         v_count_     NUMBER;
      CURSOR get_attr IS
         SELECT *
         FROM mdm_basic_data_header
         WHERE template_id = template_id_
         AND   revision = temp_revision_;
   BEGIN
        new_revision_    := Mdm_Basic_Data_Header_Api.C_Get_Next_Rev_No(template_id_);
       IF new_revision_ IS NOT NULL THEN
          OPEN get_pre_rev;
          FETCH get_pre_rev INTO temp_revision_ ;     
          CLOSE get_pre_rev;  
          
          OPEN get_Count ;
          FETCH get_Count  INTO v_count_ ;     
          CLOSE get_Count ; 
       IF v_count_ = 0 THEN
             ERROR_SYS.Record_General(lu_name_,'  : You can''t Create New Revision. Until the State is Not Activated..!');
       ELSE
       C_Create_New_Revision(template_id_,old_revision_,new_revision_);
       END IF;
       --temp_revision_ := new_revision_;
       END IF;
   
       OPEN get_attr;
       FETCH get_attr INTO rec_;
       CLOSE get_attr;
   
       Get_Id_Version_By_Keys___(objid_, objversion_,template_id_, temp_revision_);
  		Obsolete__(info_, objid_, objversion_, attr_, 'DO');      
    END C_Create_New_Revis_Struct;
       
PROCEDURE C_Create_New_Revision(
      template_id_ IN VARCHAR2,
      old_revision_ IN NUMBER,
      new_revision_ IN NUMBER )
   IS
      get_tem_     mdm_basic_data_header%ROWTYPE;
      new_rev_tem_no_ VARCHAR2(300);
      new_rev_tem_rev_ NUMBER;
      jobs_connected_ VARCHAR2(20) := 'TRUE';
      site_date_      DATE;
   
      CURSOR get_tem_data IS
         SELECT *
         FROM mdm_basic_data_header
         WHERE template_id = template_id_
         AND revision = old_revision_; 
      latest_valid_to_    DATE;
      latest_revision_    VARCHAR2(10);
      cre_new_rev_        VARCHAR2(5) := 'TRUE';
   BEGIN
   
      new_rev_tem_no_ := template_id_;
      new_rev_tem_rev_ := new_revision_;
   
      IF (new_revision_ IS NULL) THEN
         Error_SYS.Appl_General(lu_name_,'REVISIONNOTNULL: New Revision must have a value.');
      END IF;
      IF (old_revision_ = new_revision_) THEN
         Error_SYS.Appl_General(lu_name_,'REVISIONNOTSIMILAR: Old Revision and New Revision cannot be same.');
      END IF;
   
      OPEN get_tem_data;
      FETCH get_tem_data INTO get_tem_;
      CLOSE get_tem_data;
    
      C_Copy__(new_rev_tem_no_,
             new_rev_tem_rev_,
             template_id_,
             old_revision_);
        
   END C_Create_New_Revision;
   
PROCEDURE C_Copy__ (
   new_rev_tem_no_ IN  OUT VARCHAR2,
   new_rev_tem_rev_    IN  OUT NUMBER,
   template_id_      IN      VARCHAR2,
   old_revision_         IN      NUMBER )
IS
      dest_tem_action_        mdm_basic_data_header.template_id%TYPE;
      dest_tem_revision_      mdm_basic_data_header.revision%TYPE;
      
      attr_                  VARCHAR2(32000);
      objid_                 VARCHAR2(20);
      objversion_            VARCHAR2(2000);
      source_lu_name_        VARCHAR2(50):='MdmBasicDataHeader';
      destination_lu_name_   VARCHAR2(50):='MdmBasicDataHeader';
      source_key_ref_        VARCHAR2(20000);
      destination_key_ref_   VARCHAR2(20000);
      source_pm_objid_       VARCHAR2(2000);
      dest_pm_objid_         VARCHAR2(2000);
      valid_from_            DATE;
      
      source_rec_            mdm_basic_data_header_tab%ROWTYPE;
      newrec_                mdm_basic_data_header_tab%ROWTYPE;
      indrec_                Indicator_Rec;
      
      key_value_from_        VARCHAR2(2000);   
      active_rev_           mdm_basic_data_header.revision%TYPE;
   CURSOR cGet_Count IS
   select count(*) from mdm_method_list v
where v.template_id  = template_id_
and v.revision = old_revision_;
vcounr_    NUMBER;
   BEGIN
   source_rec_ := Get_Object_By_Keys___(template_id_, old_revision_);
   Client_SYS.Clear_Attr(attr_);  
	Client_SYS.Add_To_Attr('TEMPLATE_ID',source_rec_.TEMPLATE_ID, attr_);
   Client_SYS.Add_To_Attr('REVISION',new_rev_tem_rev_, attr_);
   Client_SYS.Add_To_Attr('DESCRIPTION',source_rec_.DESCRIPTION, attr_);
   Client_SYS.Add_To_Attr('CREATED_BY',FND_SESSION_API.Get_Fnd_User, attr_);
   Client_SYS.Add_To_Attr('CREATED_DATE',SYSDATE, attr_);
   Client_SYS.Add_To_Attr('NOTES',source_rec_.NOTES, attr_);
   --Client_SYS.Add_To_Attr('ROWSTATE',source_rec_.ROWSTATE, attr_);
   Client_SYS.Add_To_Attr('PROFILE_ID',source_rec_.PROFILE_ID, attr_);
   
          Unpack___(newrec_, indrec_, attr_);
         Check_Insert___(newrec_, indrec_, attr_);
         Insert___(objid_, objversion_, newrec_, attr_);
   
      dest_tem_action_         := newrec_.TEMPLATE_ID;
      new_rev_tem_no_  := newrec_.TEMPLATE_ID;
      new_rev_tem_rev_     := newrec_.revision;
      dest_tem_revision_       := newrec_.revision;     
      OPEN cGet_Count;
      FETCH cGet_Count INTO vcounr_;
      CLOSE cGet_Count;
      IF vcounr_ > 0 THEN 
      C_Copy_Template_Source___ (  template_id_, old_revision_,new_rev_tem_rev_);
      END IF;
   END C_Copy__;
   
   PROCEDURE C_Copy_Template_Source___ (
   template_id_           IN  VARCHAR2,
   old_revision_          IN  NUMBER,
   new_revision_      IN  NUMBER)
IS     
    attr_      varchar2(32000);
    info_    VARCHAR2(2000);
    objid_     VARCHAR2(50);
    objversion_ VARCHAR2(50);
    action_      VARCHAR2(10) := 'DO';
      CURSOR get_Map_info_ IS
         select * from mdm_method_list v
where v.template_id = template_id_
and v.revision = old_revision_;
      
   BEGIN
   for i in get_Map_info_ loop
          Client_Sys.Clear_Attr(attr_);   
          Client_Sys.Add_To_Attr('TEMPLATE_ID',i.template_id,attr_ );
          Client_Sys.Add_To_Attr('REVISION',new_revision_,attr_ );
          Client_Sys.Add_To_Attr('EXECUTE_SEQ',i.EXECUTE_SEQ,attr_ );
          Client_Sys.Add_To_Attr('VIEW_NAME',i.VIEW_NAME,attr_ );
          Client_Sys.Add_To_Attr('METHOD_NAME',i.METHOD_NAME,attr_ );
          Client_Sys.Add_To_Attr('ON_NEW',I.ON_NEW,attr_ );
          Client_Sys.Add_To_Attr('ON_MODIFY',i.ON_MODIFY,attr_ );
   
    Mdm_Method_List_Api.New__(info_,objid_ ,objversion_ ,attr_ ,action_ );
    
   end loop;
   
END C_Copy_Template_Source___;

@UncheckedAccess
FUNCTION Get_Status (
   template_id_       IN VARCHAR2,
   revision_ IN NUMBER) RETURN VARCHAR2
IS
   objstate_  mdm_basic_data_header_tab.rowstate%TYPE;
   CURSOR status IS
   SELECT v.rowstate
   FROM   mdm_basic_data_header_tab v
   WHERE  v.template_id = template_id_
   AND v.revision = revision_+1;
BEGIN
   OPEN status;
   FETCH status INTO objstate_;
   CLOSE status;
   RETURN Finite_State_Decode__(objstate_);
END Get_Status;



@UncheckedAccess
FUNCTION Get_Objid (
   template_id_ IN VARCHAR2,
   revision_ IN NUMBER ) RETURN VARCHAR2
IS
temp_ MDM_BASIC_DATA_HEADER.objid%TYPE;
   CURSOR get_attr IS
      SELECT v.objid
      FROM MDM_BASIC_DATA_HEADER v
      WHERE  v.template_id = template_id_
   AND v.revision = revision_+1;
BEGIN
   OPEN get_attr;
   FETCH get_attr INTO temp_;
   CLOSE get_attr;
   RETURN temp_;
END Get_Objid;


-------------------- LU SPECIFIC PRIVATE METHODS ----------------------------


-------------------- LU SPECIFIC PROTECTED METHODS --------------------------


-------------------- LU SPECIFIC PUBLIC METHODS -----------------------------

