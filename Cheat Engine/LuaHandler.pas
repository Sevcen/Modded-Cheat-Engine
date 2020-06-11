unit LuaHandler;

{todo: Split up into smaller units. 9255 lines is becomming too big}
{todo2: dll injecting lua into a target process}


{Note:
Assume all strings passed between lua are in UTF8 format
}

{$mode delphi}

interface

uses
  jwawindows, windows, vmxfunctions, Classes, dialogs, SysUtils, lua, lualib,
  lauxlib, syncobjs, cefuncproc, newkernelhandler, autoassembler, Graphics,
  controls, LuaCaller, forms, ExtCtrls, StdCtrls, comctrls, ceguicomponents,
  generichotkey, luafile, xmplayer_server, ExtraTrainerComponents, customtimer,
  menus, XMLRead, XMLWrite, DOM,ShellApi, Clipbrd, typinfo, PEInfoFunctions,
  LCLProc, strutils, registry, md5, commonTypeDefs;


const MAXTABLERECURSIONLOOKUP=2;

var
  LuaVM: Plua_State;
  LuaCS: Tcriticalsection;

function lua_strtofloat(s: string): double;
function lua_strtoint(s: string): integer;

procedure lua_register(L: Plua_State; const n: PChar; f: lua_CFunction);
function lua_pcall(L: Plua_State; nargs, nresults, errf: Integer): Integer; cdecl;
function lua_dostring(L: Plua_State; const str: PChar): Integer;

function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl;
procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl;


procedure Lua_RegisterObject(name: string; o: TObject);
function CheckIfConditionIsMetContext(context: PContext; script: string): boolean;
procedure LUA_DoScript(s: string);
function LUA_functioncall(routinetocall: string; parameters: array of const): integer;
procedure LUA_memrec_callback(memrec: pointer; routine: string);
procedure LUA_SetCurrentContextState(context: PContext);
procedure LUa_GetNewContextState(context: PContext);

function LUA_onBreakpoint(context: PContext; functionAlreadyPushed: boolean=false): boolean;
procedure LUA_onNotify(functionid: integer; sender: tobject);
function Lua_ToString(L: Plua_State; i: Integer): string;
function lua_ToCEUserData(L: PLua_state; i: integer): pointer;
function lua_tovariant(L: PLua_state; i: integer): variant;
procedure lua_pushvariant(L: PLua_state; v: variant);
procedure lua_pushrect(L: PLua_state; r: TRect);
procedure InitializeLuaScripts;
procedure InitializeLua;


function LuaValueToDescription(L: PLua_state; i: integer; recursivetablecount: integer=0): string;

function GetLuaState: PLUA_State; stdcall;


function lua_oldprintoutput:TStrings;
procedure lua_setPrintOutput(output: TStrings);

resourcestring
  rsPluginAddress = 'Plugin Address';
  rsThisTypeIsNotSupportedHere='This type is not supported here';
  rsIncorrectNumberOfParameters='Incorrect number of parameters';


implementation

uses mainunit, mainunit2, luaclass, frmluaengineunit, plugin, pluginexports,
  formsettingsunit, MemoryRecordUnit, debuggertypedefinitions, symbolhandler,
  frmautoinjectunit, simpleaobscanner, addresslist, memscan, foundlisthelper,
  cesupport, DBK32functions, sharedMemory, disassemblerComments, disassembler,
  LuaCanvas, LuaPen, LuaFont, LuaBrush, LuaPicture, LuaMenu, LuaDebug, LuaThread,
  LuaGraphic, LuaProgressBar, LuaOldD3DHook, LuaWinControl, LuaMemoryRecord,
  LuaForm, MemoryBrowserFormUnit, disassemblerviewunit, hexviewunit,
  CustomTypeHandler, LuaStructure, LuaRegion, LuaXMPlayer, LuaMemscan, LuaFoundlist,
  LuaRadioGroup, LuaRasterImage, LuaCheatComponent, LuaAddresslist, byteinterpreter,
  OpenSave, cedebugger, DebugHelper, StructuresFrm2, Assemblerunit, LuaObject,
  LuaComponent, LuaControl, LuaStrings, LuaStringlist, LuaCustomControl,
  LuaGraphicControl, LuaPanel, LuaImage, LuaButton, LuaCheckbox, LuaGroupbox,
  LuaListbox, LuaCombobox, LuaTrackbar, LuaListColumn, LuaEdit, LuaMemo, LuaCollection,
  LuaListColumns, LuaListitem, LuaListItems, LuaTimer, LuaListview, LuaGenericHotkey,
  LuaTableFile, LuaMemoryRecordHotkey, LuaMemoryView, LuaD3DHook, LuaDisassembler,
  LuaDissectCode, LuaByteTable, LuaBinary, lua_server, HotkeyHandler, LuaPipeClient,
  LuaPipeServer, LuaTreeview, LuaTreeNodes, LuaTreeNode, LuaCalendar, LuaSymbolListHandler,
  LuaCommonDialog, LuaFindDialog, LuaSettings, LuaPageControl, LuaRipRelativeScanner,
  SymbolListHandler, processhandlerunit, processlist, Globals;

resourcestring
  rsLUA_DoScriptWasNotCalledRomTheMainThread = 'LUA_DoScript was not called '
    +'from the main thread';
  rsUndefinedLuaError = 'Undefined lua error';
  rsCheatengineIsBeingAFag = 'Cheatengine is being a fag';

  rsInvalidFloat = 'Invalid floating point string:%s';
  rsInvalidInt = 'Invalid integer:%s';


var
  printoutput: TStrings;

function lua_oldprintoutput:TStrings;
begin
  result:=printoutput;
end;

procedure lua_setPrintOutput(output: TStrings);
begin
  printoutput:=output;
end;

function GetLuaState: PLUA_State; stdcall;
begin
  result:=LuaVM;
end;

procedure lua_register(L: Plua_State; const n: PChar; f: lua_CFunction);
//overriding the original lua_register to add both a lower and uppercase start
var s: string;
begin
  lua.lua_register(L, n, f);
  s:=n;
  s[1]:=chr(ord(s[1]) xor $20); //switch from uppercase to lowercase and lowercase to uppercase

  lua.lua_register(L, pchar(s), f);
end;

var luarefcs: TCriticalSection;
function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl;
begin
  luarefcs.Enter;
  result:=lauxlib.luaL_ref(l, t);
  luarefcs.leave;
end;

procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl;
begin
  luarefcs.enter;
  lauxlib.luaL_unref(l, t, ref);
  luarefcs.leave;
end;

//todo: let the user define a default error function
function lua_pcall(L: Plua_State; nargs, nresults, errf: Integer): Integer; cdecl;
var oldstack: integer;
  error: string;

  usesluaengineform: boolean;
begin
  try
    oldstack:=lua_gettop(l);
    result:=lua.lua_pcall(L, nargs, nresults, errf);
  except
    on e: exception do
    begin
      result:=LUA_ERRRUN;
      lua_settop(l, oldstack);

      lua_pushstring(l, e.Message);
    end;
  end;

  if (result=LUA_ERRRUN) and (errf=0) then //an error occured and no error handler was specified
  begin
    if GetCurrentThreadId=MainThreadID then
    begin


      //lua_Debug
      error:=Lua_ToString(l, -1);
      if (error<>'') then
      begin
        usesluaengineform:=false;
        if printoutput=nil then
        begin
          if frmLuaEngine=nil then
            frmLuaEngine:=TfrmLuaEngine.Create(application);

          printoutput:=frmLuaEngine.mOutput.Lines;
          usesluaengineform:=true;
        end;

        printoutput.add('Error:'+error);

        if (frmLuaEngine<>nil) and usesluaengineform and (frmLuaEngine.cbShowOnPrint.checked) then
          frmLuaEngine.show;

        if usesluaengineform then
          printoutput:=nil;

        lua_pop(L, lua_gettop(L));
      end;
    end;
  end;
end;

function lua_dostring(L: Plua_State; const str: PChar): Integer;
begin
  Result := luaL_loadstring(L, str);
  if Result = 0 then
    Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;

function lua_isstring(L: PLua_state; i: integer): boolean;
begin
  result := lua_type(L,i)=LUA_TSTRING;
end;

function Lua_ToString(L: Plua_State; i: Integer): string;
var r: pchar;
begin
  if lua_islightuserdata(L, i) then
    Result := inttohex(ptruint(lua_touserdata(L, i)),1)
  else
  begin
    r := lua.lua_tostring(l,i);
    if r<>nil then
      result:=r
    else
      result:='';
  end;


//unclear should there be a result:=Utf8ToAnsi(s); ?
end;

procedure lua_pushrect(L: PLua_state; r: TRect);
begin
  lua_newtable(L);
  lua_pushstring(L, 'Left');
  lua_pushinteger(L, r.left);
  lua_settable(L, -3);

  lua_pushstring(L, 'Top');
  lua_pushinteger(L, r.top);
  lua_settable(L, -3);

  lua_pushstring(L, 'Right');
  lua_pushinteger(L, r.right);
  lua_settable(L, -3);

  lua_pushstring(L, 'Bottom');
  lua_pushinteger(L, r.bottom);
  lua_settable(L, -3);
end;

procedure lua_pushvariant(L: PLua_state; v: variant);
begin
  case (tvardata(v).vtype and vartypemask) of
    varempty: lua_pushnil(L);
    varnull: lua_pushnil(L);
    varsmallint, varinteger, vardecimal, varshortint, varbyte, varword, varlongword, varint64, varqword: lua_pushinteger(L, v);
    varsingle, vardouble: lua_pushnumber(L, v);
    varboolean: lua_pushboolean(L, v);
    varstring, varustring: lua_pushstring(L, v);
    else
      lua_pushstring(L, v);
  end;
end;

function lua_tovariant(L: PLua_state; i: integer): variant;
begin
  case lua_type(L, i) of
    LUA_TNONE          : result:=nil;
    LUA_TNIL           : result:=nil;
    LUA_TBOOLEAN       : result:=lua_toboolean(L, i);
    LUA_TNUMBER        : result:=lua_tonumber(L, i);
    LUA_TSTRING        : result:=Lua_ToString(L, i);
    else
      raise exception.create(rsThisTypeIsNotSupportedHere);

  end;
end;

function lua_ToCEUserData(L: PLua_state; i: integer): pointer;
//Cheat Engine implements two types of userdata. the legacy LightUserData used in 6.2- and the Heavy UserData in 6.3+
//Heavy UserData is a pointer with a pointer to the real object, while lightuserdata is just a pointer to the object
begin
  result:=lua_touserdata(L,i);

  if (result<>nil) and (lua_isheavyuserdata(L, i)) then   //once the conversion is done this if check if it's userdata can go as it will always be userdata
    result:=ppointer(result)^;
end;

function LuaValueToDescription(L: PLua_state; i: integer; recursivetablecount: integer=0): string;
var index, count: integer;
  fieldname: string;
  valuedesc: string;
  o: tobject;

  tablepad: string;

  stackstart: integer;
begin
  result:='';


  if not lua_isnil(L, i) then
  begin
    if lua_isuserdata(L, i) then
    begin
      stackstart:=lua_gettop(L);

      o:=lua_ToCEUserData(L, i);

      try
        if o is TObject then
        begin
          result:='Object of type '+o.ClassName;
          if o is TControl then
            result:=result+#13#10+tcontrol(o).Name;
        end;
      except
      end;

      index:=lua_gettop(l);
      lua_settop(l, stackstart);
    end
    else
    if lua_iscfunction(L, i) then
      result:='native function'
    else
    if lua_isfunction(L, i) then
      result:='function'
    else
    if lua_istable(L, i) then
    begin
      result:='table';

      if recursivetablecount<MAXTABLERECURSIONLOOKUP then
      begin
        tablepad:=DupeString('   ',recursivetablecount);

        stackstart:=lua_gettop(l);


        result:=result+#13#10+tablepad+'['+#13#10;;
        count:=10;
        lua_pushvalue(L, i);
        index:=lua_gettop(L);
        lua_pushnil(L);  //first key (nil)
        while lua_next(L, index)<>0 do
        begin
          count:=count-1;
          if count<0 then
          begin

            result:=result+tablepad+'...'+#13#10;;
            break;
          end;

          if lua_type(L,-2)=LUA_TSTRING then
            fieldname:=Lua_ToString(L, -2)
          else
            fieldname:=inttostr(lua_tointeger(L, -2));


          valuedesc:=LuaValueToDescription(L, -1, recursivetablecount+1);

          result:=result+tablepad+'   '+fieldname+' = '+valuedesc+#13#10;


          lua_pop(L, 1); //pop the value, keep the key
        end;

//        lua_pop(L,1); //pop the pushvalue from before



        lua_settop(l, stackstart);

        result:=result+tablepad+']';
      end;
    end
    else
    if lua_isboolean(L, i) then
      result:=BoolToStr(lua_toboolean(L,i),'true','false')
    else
      result:=Lua_ToString(L, i);
  end
  else
    result:='nil';
end;

procedure InitializeLuaScripts;
var f: string;
  i,r: integer;
  pc: pchar;
  DirInfo: TSearchRec;
begin


  f:='main.lua';
  if not FileExists(f) then //perhaps in the cedir
  begin
    f:=CheatEngineDir+'main.lua';
    if not FileExists(f) then
    begin
      //try the defines only then
      f:='defines.lua';
      if not FileExists(f) then
      begin
        f:=CheatEngineDir+'defines.lua';
        if not FileExists(f) then
          exit;
      end;
    end;
  end;

  //file exists

  LuaCS.Enter;
  try
    if lua_dofile(luavm, pchar(f))<>0 then
    begin
      i:=lua_gettop(luavm);
      if i>0 then
      begin
        pc:=lua_tolstring(luavm, -1,nil);
        if pc<>nil then
          showmessage('main.lua error:'+pc)
        else
          showmessage('main.lua error');
      end
      else showmessage('main.lua error');

    end;

    lua_pop(LuaVM, lua_gettop(luavm)); //reset stack
  finally
    LuaCS.Leave;
  end;

  //autorun folder
  ZeroMemory(@DirInfo,sizeof(TSearchRec));
  r := FindFirst(CheatEngineDir+'autorun'+pathdelim+'*.lua', FaAnyfile, DirInfo);
  while (r = 0) do
  begin
    if (DirInfo.Attr and FaVolumeId <> FaVolumeID) then
    begin
      if ((DirInfo.Attr and FaDirectory) <> FaDirectory) then
      begin
        i:=lua_dofile(luavm, pchar(CheatEngineDir+'autorun'+pathdelim+DirInfo.name));
        if i<>0 then //error
        begin
          i:=lua_gettop(luavm);
          if i>0 then
          begin
            pc:=lua_tolstring(luavm, -1,nil);
            if pc<>nil then
              showmessage(DirInfo.name+' error:'+pc)
            else
              showmessage(DirInfo.name+' error');
          end
          else showmessage(DirInfo.name+' error');
        end;

        //reset stack
        lua_pop(LuaVM, lua_gettop(luavm));
      end;
    end;
    r := FindNext(DirInfo);
  end;
  FindClose(DirInfo);



end;

function lua_strtofloat(s: string): double;
var stackpos: integer;
  s2: integer;
begin
  LuaCS.enter;
  try
    stackpos:=lua_gettop(luavm);
    if lua_dostring(luavm, pchar('return '+s) )=0 then
    begin
      s2:=lua_gettop(luavm);
      if (s2-stackpos)>0 then
        result:=lua_tonumber(luavm, stackpos-s2)
      else
        raise exception.create(Format(rsInvalidFloat, [s]));
    end
    else
      raise exception.create(Format(rsInvalidFloat, [s]));

  finally
    lua_settop(luavm, stackpos);
    LuaCS.leave;
  end;
end;

function lua_strtoint(s: string): integer;
var stackpos: integer;
  s2: integer;
begin
  LuaCS.enter;
  try
    stackpos:=lua_gettop(luavm);
    if lua_dostring(luavm, pchar('return '+s) )=0 then
    begin
      s2:=lua_gettop(luavm);
      if (s2-stackpos)>0 then
        result:=lua_tointeger(luavm, stackpos-s2)
      else
        raise exception.create(Format(rsInvalidInt, [s]));
    end
    else
      raise exception.create(Format(rsInvalidInt, [s]));

  finally
    lua_settop(luavm, stackpos);
    LuaCS.leave;
  end;

end;

procedure Lua_RegisterObject(name: string; o: TObject);
var s: integer;
begin
  LuaCS.enter;
  try
    s:=lua_gettop(LuaVM);
    luaclass_newClass(LuaVM, o);
    lua_setglobal(LuaVM, pchar(name));

    lua_settop(LuaVM, s);
  finally
    LuaCS.Leave;
  end;
end;

function LUA_onBreakpoint(context: PContext; functionAlreadyPushed: boolean=false): boolean;
var p: integer;
begin
  result:=false;
  LuaCS.enter;
  try
    LUA_SetCurrentContextState(context);


    if not functionAlreadyPushed then
    begin
      lua_pop(LuaVM, lua_gettop(luavm)); //clear it just to be sure

      lua_getfield(luavm, LUA_GLOBALSINDEX, pchar('debugger_onBreakpoint'));
      p:=lua_gettop(luavm);
      if p=0 then exit;
    end;

    if lua_isfunction(luavm, -1) then //extra check
    begin
      if lua_pcall(LuaVM, 0, 1, 0)=0 then
      begin
        p:=lua_gettop(luavm);

        if (p=1) then //only 1 parameter returned
          result:=lua_tointeger(luavm, -1)<>0;  //return the result is not 0


        lua_pop(LuaVM, lua_gettop(luavm)); //clear stack

        //set new state if changes where made
        LUA_GetNewContextState(context);
      end;
    end;



  finally
    lua_pop(LuaVM, lua_gettop(luavm));
    LuaCS.leave;
  end;
end;

procedure LUA_SetCurrentContextState(context: PContext);
begin
  LuaCS.Enter;
  try

    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rax{$else}eax{$endif});
    lua_setglobal(luavm, 'RAX');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rax{$else}eax{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EAX');

    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rbx{$else}ebx{$endif});
    lua_setglobal(luavm, 'RBX');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rbx{$else}ebx{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EBX');


    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rcx{$else}ecx{$endif});
    lua_setglobal(luavm, 'RCX');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rcx{$else}ecx{$endif} and $ffffffff);
    lua_setglobal(luavm, 'ECX');

    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rdx{$else}edx{$endif});
    lua_setglobal(luavm, 'RDX');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rdx{$else}edx{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EDX');


    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rsi{$else}esi{$endif});
    lua_setglobal(luavm, 'RSI');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rsi{$else}esi{$endif} and $ffffffff);
    lua_setglobal(luavm, 'ESI');


    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rdi{$else}edi{$endif});
    lua_setglobal(luavm, 'RDI');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rdi{$else}edi{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EDI');


    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}Rbp{$else}ebp{$endif});
    lua_setglobal(luavm, 'RBP');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}RBP{$else}eBP{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EBP');


    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}RSP{$else}eSP{$endif});
    lua_setglobal(luavm, 'RSP');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}RSP{$else}eSP{$endif} and $ffffffff);
    lua_setglobal(luavm, 'ESP');

    {$ifdef cpu64}
    lua_pushinteger(luavm, context.{$ifdef cpu64}RIP{$else}eIP{$endif});
    lua_setglobal(luavm, 'RIP');
    {$endif}
    lua_pushinteger(luavm, context.{$ifdef cpu64}RIP{$else}eIP{$endif} and $ffffffff);
    lua_setglobal(luavm, 'EIP');

    lua_pushinteger(luavm, context.EFlags);
    lua_setglobal(luavm, 'EFLAGS');



    {$ifdef cpu64}
    lua_pushinteger(luavm, context.r8);
    lua_setglobal(luavm, 'R8');

    lua_pushinteger(luavm, context.r9);
    lua_setglobal(luavm, 'R9');

    lua_pushinteger(luavm, context.r10);
    lua_setglobal(luavm, 'R10');

    lua_pushinteger(luavm, context.r11);
    lua_setglobal(luavm, 'R11');

    lua_pushinteger(luavm, context.r12);
    lua_setglobal(luavm, 'R12');

    lua_pushinteger(luavm, context.r13);
    lua_setglobal(luavm, 'R13');

    lua_pushinteger(luavm, context.r14);
    lua_setglobal(luavm, 'R14');

    lua_pushinteger(luavm, context.r15);
    lua_setglobal(luavm, 'R15');
    {$endif}

  finally
    LuaCS.Leave;
  end;
end;

procedure LUA_GetNewContextState(context: PContext);
begin
  lua_getglobal(luavm, 'EFLAGS');
  context.EFLAGS:=lua_tointeger(luavm, -1);
  lua_pop(luavm,1);

  if not processhandler.is64bit then
  begin
    lua_getglobal(luavm, 'EAX');
    context.{$ifdef cpu64}rax{$else}eax{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'EBX');
    context.{$ifdef cpu64}rbx{$else}ebx{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'ECX');
    context.{$ifdef cpu64}rcx{$else}ecx{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'EDX');
    context.{$ifdef cpu64}rdx{$else}edx{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'ESI');
    context.{$ifdef cpu64}rsi{$else}esi{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'EDI');
    context.{$ifdef cpu64}rdi{$else}edi{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'EBP');
    context.{$ifdef cpu64}rbp{$else}ebp{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'ESP');
    context.{$ifdef cpu64}rsp{$else}esp{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);


    lua_getglobal(luavm, 'EIP');
    context.{$ifdef cpu64}rip{$else}eip{$endif}:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

  end
  else
  begin
  {$ifdef cpu64}
    lua_getglobal(luavm, 'RAX');
    context.RAX:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RBX');
    context.RBX:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RCX');
    context.RCX:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RDX');
    context.RDX:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RSI');
    context.RSI:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RDI');
    context.RDI:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RBP');
    context.RBP:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RSP');
    context.RSP:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'RIP');
    context.RIP:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R8');
    context.R8:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R9');
    context.R9:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R10');
    context.R10:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R11');
    context.R11:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R12');
    context.R12:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R13');
    context.R13:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R14');
    context.R14:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);

    lua_getglobal(luavm, 'R15');
    context.R15:=lua_tointeger(luavm, -1);
    lua_pop(luavm,1);
  {$endif}

  end;
end;

procedure LUA_DoScript(s: string);
var i: integer;
  pc: pchar;

  stack: integer;
begin
  if GetCurrentThreadId<>MainThreadID then raise exception.create(rsLUA_DoScriptWasNotCalledRomTheMainThread);

  LUACS.Enter;
  try
    stack:=lua_gettop(luavm);
    i:=lua_dostring(luavm, pchar(s));
    if i<>0 then
    begin
      pc:=lua.lua_tostring(luavm, -1);
      if pc<>nil then
        raise Exception.Create(pc)
      else
        raise exception.create(rsUndefinedLuaError);

    end;
  finally
    lua_settop(luavm, stack);
    LUACS.Leave;
  end;
end;

procedure LUA_onNotify(functionid: integer; sender: tobject);
begin
  LUACS.enter;
  try
    lua_rawgeti(Luavm, LUA_REGISTRYINDEX, functionid);

    lua_pushlightuserdata(Luavm, sender);
    lua_pcall(Luavm, 1, 0, 0);
  finally
    lua_pop(luavm, lua_gettop(luavm)); //clear the stack
    LUACS.Leave;
  end;
end;

procedure LUA_memrec_callback(memrec: pointer; routine: string);
var m: TMemoryrecord;
  p: integer;
begin
  LuaCS.Enter;
  try
    m:=memrec;

    lua_getfield(luavm, LUA_GLOBALSINDEX, pchar(routine));

    p:=lua_gettop(luavm);
    if p<>0 then
    begin
      if lua_isfunction(luavm, -1) then
      begin
        lua_pushlightuserdata(luavm, memrec);
        lua_pcall(luavm, 1, 0, 0);
      end;


    end;
  finally
    lua_pop(luavm,lua_gettop(luavm));
    luacs.Leave;
  end;
end;

function LUA_functioncall(routinetocall: string; parameters: array of const): integer;
var i: integer;
  c: string;
  p: integer;
  oldstack: integer;
begin
  result:=-1;
  oldstack:=lua_gettop(luavm);

 // if luacs.TryEnter then
  begin
    try
      //check if the routine exists
      lua_getfield(luavm, LUA_GLOBALSINDEX, pchar(routinetocall));

      p:=lua_gettop(luavm);
      if p<>oldstack then
      begin
        if lua_isfunction(luavm, -1) then
        begin
          //routine exists, fill in the parameters
          for i:=0 to length(parameters)-1 do
          begin
            case parameters[i].VType of
              system.vtInteger : lua_pushinteger(LUAVM, parameters[i].VInteger);
              system.vtBoolean: lua_pushboolean(LUAVM, parameters[i].VBoolean);
              system.vtChar:
              begin
                c:=parameters[i].VChar;
                lua_pushstring(LUAVM, c);
              end;
              system.vtExtended: lua_pushnumber(LUAVM, parameters[i].VExtended^);
              system.vtString: lua_pushstring(LUAVM, pchar(parameters[i].VString));
              system.vtPointer: lua_pushlightuserdata(LUAVM, parameters[i].VPointer);
              system.vtPChar: lua_pushstring(LUAVM, parameters[i].VPChar);
              system.vtObject: lua_pushlightuserdata(LUAVM, pointer(parameters[i].VObject));
              system.vtClass: lua_pushlightuserdata(LUAVM, pointer(parameters[i].VClass));
              system.vtWideChar, vtPWideChar, vtVariant, vtInterface,
                vtWideString: lua_pushstring(LUAVM, rsCheatengineIsBeingAFag);
              system.vtAnsiString: lua_pushstring(LUAVM, pchar(parameters[i].VAnsiString));
              system.vtCurrency: lua_pushnumber(LUAVM, parameters[i].VCurrency^);
              system.vtInt64:
              begin
                if (parameters[i].VInt64^<=$ffffffff) then
                  lua_pushinteger(LUAVM, parameters[i].VInt64^)
                else
                  lua_pushlightuserdata(LUAVM, pointer(parameters[i].VInt64^));
              end;
              system.vtQWord:
              begin
                if (parameters[i].VQWord^<=$ffffffff) then
                  lua_pushinteger(LUAVM, parameters[i].VQWord^)
                else
                  lua_pushlightuserdata(LUAVM, pointer(parameters[i].VQWord^));
              end;
            end;

          end;

          lua_pcall(luavm, length(parameters), 1, 0);
          i:=lua_gettop(luavm);
          if i>0 then //it has a parameter
            result:=lua_tointeger(luavm, -1);
        end;


      end;


    finally
      lua_settop(luavm, oldstack);
 //     luacs.leave;
    end;

  end;
end;

 {
procedure LUA_callback(routine: string; parameters: tvararray);
var m: TMemoryrecord;
  p: integer;
begin
  LuaCS.Enter;
  try
    m:=memrec;

    lua_getfield(luavm, LUA_GLOBALSINDEX, pchar(routine));

    p:=lua_gettop(luavm);
    if p<>0 then
    begin
      if lua_isfunction(luavm, -1) then
      begin
        lua_pushlightuserdata(luavm, memrec);
        lua_pcall(luavm, 1, 0, 0);
      end;


    end;
  finally
    lua_pop(luavm,lua_gettop(luavm));
    luacs.Leave;
  end;
end; }

function CheckIfConditionIsMetContext(context: PContext; script: string): boolean;
{
precondition: script returns a value (so already has the 'return ' part appended for single line scripts)
}
var i: integer;
begin
  result:=false;
  LuaCS.Enter;
  try
    LUA_SetCurrentContextState(context);

    if lua_dostring(luavm, pchar(script))=0 then
    begin
      i:=lua_gettop(LuaVM);
      if i=1 then //valid return
        result:=lua_toboolean(LuaVM, -1);
    end;
  finally
    lua_pop(LuaVM, lua_gettop(luavm));
    LuaCS.Leave;
  end;
end;

function LuaPanic(L: Plua_State): Integer; cdecl;
begin
  result:=0;
  lua_pop(LuaVM, lua_gettop(luavm));
  raise exception.create('LUA panic!');
end;


function sleep(L: PLua_State): integer; cdecl;
var
  parameters: integer;
begin
  parameters:=lua_gettop(L);

  result:=0;

  if parameters=1 then
    windows.sleep(lua_tointeger(L, -1));

  lua_pop(L, parameters);
end;

function print2(param: pointer): pointer;
var usesluaengineform: boolean;
begin
  usesluaengineform:=false;

  if printoutput=nil then
  begin
    if frmLuaEngine=nil then
      frmLuaEngine:=TfrmLuaEngine.Create(MemoryBrowser);

    printoutput:=frmLuaEngine.mOutput.Lines;
    usesluaengineform:=true;
  end;

  printoutput.add(pchar(param));

  if (frmLuaEngine<>nil) and usesluaengineform and (frmLuaEngine.cbShowOnPrint.checked) then
    frmLuaEngine.show;

  if usesluaengineform then
    printoutput:=nil;

  result:=nil;
end;

function print(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  s: string;

  str: string;
  i: integer;
begin
  parameters:=lua_gettop(L);
  if parameters=0 then exit;

  str:='';
  for i:=-parameters to -1 do
  begin
    if lua_isuserdata(L,i) then
      s:=inttohex(ptruint(lua_ToCEUserData(L, i)),8)
    else
      s:=lua_tostring(L, i);

    str:=str+s+' ';
  end;

  if str<>'' then
    pluginsync(print2, @str[1]);

  lua_pop(L, parameters);
  lua_pushstring(L, str);
  result:=1;
end;

function inputQuery_lua(L: PLua_State): integer; cdecl;
var
  caption, prompt, value: string;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(l);
  if parameters=3 then
  begin
    caption:=Lua_ToString(L, 1);
    prompt:=Lua_ToString(L, 2);
    value:=Lua_ToString(L, 3);
    if InputQuery(caption, prompt, value) then
    begin
      result:=1;
      lua_pushstring(L, value);
    end;
  end;

end;

function showMessage_lua(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  s: string;
begin
  parameters:=lua_gettop(L);
  if parameters=0 then exit;

  if lua_islightuserdata(l,-1) then
    s:=inttohex(ptruint(lua_touserdata(L, -1)),8)
  else
    s:=lua_tostring(L, -1);

  ShowMessage(s);

//  ce_showmessage(pchar(s));

  lua_pop(L, parameters);
  result:=0;
end;

function readIntegerEx(L: PLua_State; processhandle: thandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: integer;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=1 then
    begin
      //ShowMessage(inttostr(lua_type(L, -1)));

      if lua_isstring(L, -1) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
      end
      else
        address:=lua_tointeger(L,-1);

      lua_pop(L, parameters);

      v:=0;
      if ReadProcessMemory(processhandle, pointer(address), @v, sizeof(v), r) then
      begin
        lua_pushinteger(L, dword(v));
        result:=1;
      end;

    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function readIntegerLocal(L: PLua_State): integer; cdecl;
begin
  result:=readIntegerEx(L, GetCurrentProcess);
end;

function readInteger(L: PLua_State): integer; cdecl;
begin
  result:=readIntegerEx(L, ProcessHandle);
end;

function readQwordEx(L: PLua_State; processhandle: thandle): integer; cdecl;
var
  parameters: Qword;
  address: ptruint;

  v: Qword;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=1 then
    begin
      //ShowMessage(inttostr(lua_type(L, -1)));

      if lua_isstring(L, -1) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
      end
      else
        address:=lua_tointeger(L,-1);

      lua_pop(L, parameters);

      v:=0;
      if ReadProcessMemory(processhandle, pointer(address), @v, sizeof(v), r) then
      begin
        lua_pushinteger(L, v);
        result:=1;
      end;

    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function readQwordLocal(L: PLua_State): integer; cdecl;
begin
  result:=readQwordEx(L, GetCurrentProcess);
end;

function readQword(L: PLua_State): integer; cdecl;
begin
  result:=readQwordEx(L, ProcessHandle);
end;

function readPointerLocal(L: PLua_State): integer; cdecl;
begin
{$ifdef cpu64}
  result:=readQwordLocal(L);
{$else}
  result:=readIntegerLocal(L);
{$endif}
end;

function readPointer(L: PLua_State): integer; cdecl;
begin
  if processhandler.is64Bit then
    result:=readQword(L)
  else
    result:=readInteger(L);
end;

function readFloatEx(L: PLua_State; ProcessHandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: single;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=1 then
    begin
      if lua_isstring(L, -1) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
      end
      else
        address:=lua_tointeger(L,-1);

      lua_pop(L, parameters);

      v:=0;
      if ReadProcessMemory(processhandle, pointer(address), @v, sizeof(v), r) then
      begin
        lua_pushnumber(L, v);
        result:=1;
      end;

    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function readFloatLocal(L: PLua_State): integer; cdecl;
begin
  result:=readFloatEx(L, GetCurrentProcess);
end;

function readFloat(L: PLua_State): integer; cdecl;
begin
  result:=readFloatEx(L, ProcessHandle);
end;

function readDoubleEx(L: PLua_State; ProcessHandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: double;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=1 then
    begin
      if lua_isstring(L, -1) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
      end
      else
        address:=lua_tointeger(L,-1);

      lua_pop(L, parameters);

      v:=0;
      if ReadProcessMemory(processhandle, pointer(address), @v, sizeof(v), r) then
      begin
        lua_pushnumber(L, v);
        result:=1;
      end;

    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function readDoubleLocal(L: PLua_State): integer; cdecl;
begin
  result:=readDoubleEx(L, GetCurrentProcess);
end;

function readDouble(L: PLua_State): integer; cdecl;
begin
  result:=readDoubleEx(L, processhandle);
end;

function readStringEx(L: PLua_State; ProcessHandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: pchar;
  w: pwidechar absolute v;
  s: string;
  r: PtrUInt;
  maxsize: integer;

  usewidechar: boolean;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters>=1 then
    begin
      if lua_isstring(L, -parameters) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,1))
      end
      else
        address:=lua_tointeger(L,-parameters);

      if parameters>=2 then
        maxsize:=lua_tointeger(L,2)
      else
        maxsize:=50;

      if parameters>=3 then
        usewidechar:=lua_toboolean(L,3)
      else
        usewidechar:=false;

      lua_pop(L, parameters);

      getmem(v,maxsize+1);
      try
        if ReadProcessMemory(processhandle, pointer(address), v, maxsize, r) then
        begin
          v[maxsize]:=#0;
          if usewidechar then
          begin
            v[maxsize-1]:=#0;
            s:=w;
          end
          else
            s:=v;


          lua_pushstring(L, s);
          result:=1;
        end;


      finally
        freemem(v);
      end;

    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function readStringLocal(L: PLua_State): integer; cdecl;
begin
  result:=readStringEx(L, GetCurrentProcess);
end;

function readString(L: PLua_State): integer; cdecl;
begin
  result:=readStringEx(L, processhandle);
end;

function writeIntegerEx(L: PLua_State; processhandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: integer;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=2 then
    begin
      if lua_isstring(L, -2) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-2))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
      end
      else
        address:=lua_tointeger(L,-2);

      v:=lua_tointeger(L, -1);

      lua_pop(L, parameters);
      lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), @v, sizeof(v), r));
      result:=1;
    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function writeIntegerLocal(L: PLua_State): integer; cdecl;
begin
  result:=writeIntegerEx(L, GetCurrentProcess);
end;

function writeInteger(L: PLua_State): integer; cdecl;
begin
  result:=writeIntegerEx(L, processhandle);
end;

function writeQwordEx(L: PLua_State; processhandle: THandle): integer; cdecl;
var
  parameters: Qword;
  address: ptruint;

  v: Qword;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=2 then
    begin
      if lua_isstring(L, -2) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-2))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
      end
      else
        address:=lua_tointeger(L,-2);

      v:=lua_tointeger(L, -1);

      lua_pop(L, parameters);
      lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), @v, sizeof(v), r));
      result:=1;
    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function writeQwordLocal(L: PLua_State): integer; cdecl;
begin
  result:=writeQwordEx(L, GetCurrentProcess);
end;

function writeQword(L: PLua_State): integer; cdecl;
begin
  result:=writeQwordEx(L, processhandle);
end;

function writePointerLocal(L: PLua_State): integer; cdecl;
begin
{$ifdef cpu64}
  result:=writeQwordLocal(L);
{$else}
  result:=writeIntegerLocal(L);
{$endif}
end;

function writePointer(L: PLua_State): integer; cdecl;
begin
  if processhandler.is64bit then
    result:=writeQword(L)
  else
    result:=writeInteger(L);
end;

function writeFloatEx(L: PLua_State; processhandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: single;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=2 then
    begin
      if lua_isstring(L, -2) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-2))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
      end
      else
        address:=lua_tointeger(L,-2);

      v:=lua_tonumber(L, -1);

      lua_pop(L, parameters);


      lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), @v, sizeof(v), r));
      result:=1;
    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function writeFloatLocal(L: PLua_State): integer; cdecl;
begin
  result:=writeFloatEx(L, GetCurrentProcess);
end;

function writeFloat(L: PLua_State): integer; cdecl;
begin
  result:=writeFloatEx(L, processhandle);
end;


function writeDoubleEx(L: PLua_State; processhandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: double;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters=2 then
    begin
      if lua_isstring(L, -2) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-2))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
      end
      else
        address:=lua_tointeger(L,-2);

      v:=lua_tonumber(L, -1);

      lua_pop(L, parameters);

      lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), @v, sizeof(v), r));
      result:=1;
    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function writeDoubleLocal(L: PLua_State): integer; cdecl;
begin
  result:=writeDoubleEx(L, GetCurrentProcess);
end;

function writeDouble(L: PLua_State): integer; cdecl;
begin
  result:=writeDoubleEx(L, processhandle);
end;

function writeStringEx(L: PLua_State; processhandle: THandle): integer; cdecl;
var
  parameters: integer;
  address: ptruint;

  v: pchar;
  usewidechar: boolean;

  w: widestring;
  r: PtrUInt;
begin
  result:=0;
  try
    parameters:=lua_gettop(L);
    if parameters>=2 then
    begin
      if lua_isstring(L, 1) then
      begin
        if processhandle=GetCurrentProcess then
          address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,1))
        else
          address:=symhandler.getAddressFromNameL(lua_tostring(L,1))
      end
      else
        address:=lua_tointeger(L,1);

      v:=lua.lua_tostring(L, 2);

      if parameters>=3 then
        usewidechar:=lua.lua_toboolean(L, 3)
      else
        usewidechar:=false;

      lua_pop(L, parameters);

      if usewidechar then
      begin
        //convert the ansi sring to a widestring
        w:=v;
        lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), @w[1], length(w)*2, r));
      end
      else
        lua_pushboolean(L, WriteProcessMemory(processhandle, pointer(address), v, length(v), r));

      result:=1;
    end;
  except
    result:=0;
    lua_pop(L, lua_gettop(L));
  end;
end;

function writeStringLocal(L: PLua_State): integer; cdecl;
begin
  result:=writeStringEx(L, GetCurrentProcess);
end;

function writeString(L: PLua_State): integer; cdecl;
begin
  result:=writeStringEx(L, processhandle);
end;

function readBytesEx(processhandle: dword; L: PLua_State): integer; cdecl;
var parameters: integer;
  addresstoread: ptruint;
  bytestoread: integer;
  i: integer;
  bytes: array of byte;
  x: PtrUInt;
  tableversion: boolean;
begin
  tableversion:=false;
  result:=0;
  parameters:=lua_gettop(L);

  if lua_isstring(L, -parameters) then
  begin
    if processhandle=GetCurrentProcess then
      addresstoread:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-parameters))
    else
      addresstoread:=symhandler.getAddressFromNameL(lua_tostring(L,-parameters));
  end
  else
    addresstoread:=lua_tointeger(L,-parameters);

  if parameters>1 then
  begin
    bytestoread:=lua_tointeger(L,-parameters+1);

    if parameters>2 then
      tableversion:=lua_toboolean(L, -parameters+2);

  end
  else
    bytestoread:=1;

  lua_pop(L, parameters);

  setlength(bytes,bytestoread);
  ZeroMemory(@bytes[0], bytestoread);
  if ReadProcessMemory(processhandle, pointer(addresstoread), @bytes[0], bytestoread, x) then
  begin
    if tableversion then
    begin
      lua_newtable(L);
      for i:=0 to x-1 do
      begin
        lua_pushinteger(L, i+1);
        lua_pushinteger(L, bytes[i]);
        lua_settable(L, -3);
      end;
      result:=1;
    end
    else
    begin
      for i:=0 to x-1 do
        lua_pushinteger(L,bytes[i]);
      result:=x;
    end;
  end;


end;


function writeBytesEx(processhandle: dword; L: PLua_State): integer;
var
  parameters, parameters2: integer;
  bytes: array of byte;
  i,j: integer;
  bytecount: integer;
  address: ptruint;
  x: PtrUInt;
  oldprotect: dword;
  b: byte;
begin
  parameters:=lua_gettop(L);
  if parameters=0 then exit;



  if lua_isstring(L, -parameters) then
  begin
    if processhandle=GetCurrentProcess then
      address:=selfsymhandler.getAddressFromNameL(lua_tostring(L,-parameters))
    else
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-parameters))
  end
  else
    address:=lua_tointeger(L,-parameters);

  bytecount:=0;
  if lua_istable(L, 2) then
  begin
    parameters2:=lua_objlen(L, 2);
    setlength(bytes, parameters2);



    for i:=1 to parameters2 do
    begin
      lua_pushinteger(L,i);
      lua_gettable(L, 2);

      if lua_isnumber(L,-1) then
      begin
        j:=lua_tointeger(L,-1);
        bytes[bytecount]:=j;
        inc(bytecount);
      end;
      lua_pop(L,1);
    end;


  end
  else
  begin
    setlength(bytes,parameters-1);

    bytecount:=0;
    for i:=(-parameters)+1 to -1 do
    begin
      b:=lua_tointeger(L,i);
      bytes[bytecount]:=b;
      inc(bytecount);
    end;

  end;

  x:=0;
  VirtualProtectEx(processhandle, pointer(address), bytecount, PAGE_EXECUTE_READWRITE, oldprotect);
  WriteProcessMemory(processhandle, pointer(address), @bytes[0], bytecount, x);
  VirtualProtectEx(processhandle, pointer(address), bytecount, oldprotect, oldprotect);


  lua_pop(L, parameters);
  lua_pushinteger(L, x);    //return the number of bytes written

  result:=1;  //return 1 value
end;

function writeBytes(L: PLua_state): integer; cdecl;
begin
  result:=writeBytesEx(processhandle, L);
end;

function readBytes(L: PLua_State): integer; cdecl;
begin
  result:=readBytesEx(processhandle, L);
end;

function writeBytesLocal(L: PLua_state): integer; cdecl;
begin
  result:=writebytesEx(getcurrentprocess, L);
end;

function readBytesLocal(L: PLua_State): integer; cdecl;
begin
  result:=readbytesEx(getcurrentprocess, L);
end;

function autoAssemble_lua(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  code: TStringlist;
  r: boolean;
  targetself: boolean;
  CEAllocArray: TCEAllocArray;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=0 then
  begin
    lua_pushboolean(L, false);
    exit;
  end;

  code:=tstringlist.create;
  try
    code.text:=lua_tostring(L, -parameters);
    if parameters>1 then
      targetself:=lua_toboolean(L, -parameters+1)
    else
      targetself:=false;

    try
      r:=autoassemble(code, false, true, false, targetself, CEAllocArray);
    except
      r:=false;
    end;

    lua_pop(L, parameters);
    lua_pushboolean(L, r);
  finally
    code.free;
  end;

  result:=1;
end;

function getPixel(L: PLua_State): integer; cdecl;
var t:TCanvas;
  parameters: integer;
  r: dword;
  x,y: integer;
begin
  result:=0; //return 0 paramaters
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    x:=lua_tointeger(L, -2); //x
    y:=lua_tointeger(L, -1); //y
    lua_pop(L, 2);

    try
      t:=TCanvas.create;
      try
        t.Handle:=getdc(0);
        r:=t.Pixels[x,y];

        lua_pushinteger(L,r); //push the color on the stack
        result:=1; //tell lue I put 1 parameter on the stack

        ReleaseDC(0,t.handle);
      finally
        t.free;
      end;
    except
    end;
  end else lua_pop(L, parameters);
end;

function getMousePos(L: PLua_State): integer; cdecl;
var t:TCanvas;
  parameters: integer;
  cp: Tpoint;
begin
  result:=0; //return 0 parameters
  parameters:=lua_gettop(L);
  if parameters=0 then
  begin
    cp:=mouse.CursorPos;
    lua_pushinteger(L, cp.x);
    lua_pushinteger(L, cp.y);
    result:=2;   //return 2 parameters
  end else lua_pop(L, parameters);
end;

function setMousePos(L: PLua_State): integer; cdecl;
var t:TCanvas;
  parameters: integer;
  cp: Tpoint;
begin
  result:=0; //return 0 parameters
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    cp.x:=lua_tointeger(L, -2); //x
    cp.y:=lua_tointeger(L, -1); //y
    lua_pop(L, 2);

    mouse.CursorPos:=cp;
  end else lua_pop(L, parameters);
end;

function createTableEntry(L: PLua_State): integer; cdecl;
var parameters: integer;
  r: pointer;
begin
  lua_pop(L, lua_gettop(L)); //clear the stack

  r:=ce_createTableEntry;
  luaclass_newClass(L, r);
  result:=1;
end;

function getTableEntry(L: PLua_State): integer; cdecl;
var parameters: integer;
  description: pchar;
  r: pointer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    description:=lua.lua_tostring(L,-1); //description

    lua_pop(L, parameters);  //clear stack

    r:=ce_getTableEntry(description);
    if r<>nil then
    begin
      luaclass_newClass(L, r);
      result:=1;
    end;
  end else lua_pop(L, parameters);
end;



function isKeyPressed(L: PLua_State): integer; cdecl;
var parameters: integer;
  keyinput: pchar;
  key: integer;
  w: word;
  r: boolean;
begin
  result:=0;
  r:=false;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L,-1) then  //char given instead of keycode
    begin
      keyinput:=lua.lua_tostring(L,-1);
      if keyinput<>nil then
        key:=ord(keyinput[0]);
    end
    else

    if lua_isnumber(L,-1) then //keycode
      key:=lua_tointeger(L,-1);

    lua_pop(L, parameters); //parameters have been fetched, clear stack

    if key<>0 then
    begin
      w:=GetAsyncKeyState(key);
      r:=(w and 1)=1;

      if not r then
        r:=((w shr 15) and 1)=1;

      lua_pushboolean(L, r);
      result:=1;
    end;

  end else lua_pop(L, parameters);

end;


function keyDown(L: PLua_State): integer; cdecl;
var parameters: integer;
  keyinput: pchar;
  key: integer;
  w: word;
  r: boolean;
begin
  result:=0;
  r:=false;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L,-1) then  //char given isntead of keycode
    begin
      keyinput:=lua.lua_tostring(L,-1);
      if keyinput<>nil then
        key:=ord(keyinput[0]);
    end
    else
    if lua_isnumber(L,-1) then //keycode
      key:=lua_tointeger(L,-1);


    if key<>0 then
      keybd_event(key, 0,0,0);

  end;
  lua_pop(L, parameters);
end;


function keyUp(L: PLua_State): integer; cdecl;
var parameters: integer;
  keyinput: pchar;
  key: integer;
  w: word;
  r: boolean;
begin
  result:=0;
  r:=false;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L,-1) then  //char given isntead of keycode
    begin
      keyinput:=lua.lua_tostring(L,-1);
      if keyinput<>nil then
        key:=ord(keyinput[0]);
    end
    else
    if lua_isnumber(L,-1) then //keycode
      key:=lua_tointeger(L,-1);


    if key<>0 then
      keybd_event(key, 0,KEYEVENTF_KEYUP,0);

  end;
  lua_pop(L, parameters);
end;

function doKeyPress(L: PLua_State): integer; cdecl;
var parameters: integer;
  keyinput: pchar;
  key: integer;
  w: word;
  r: boolean;
begin
  result:=0;
  r:=false;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L,-1) then  //char given isntead of keycode
    begin
      keyinput:=lua.lua_tostring(L,-1);
      if keyinput<>nil then
        key:=ord(keyinput[0]);
    end
    else
    if lua_isnumber(L,-1) then //keycode
      key:=lua_tointeger(L,-1);


    if key<>0 then
    begin
      keybd_event(key, 0, 0, 0);
      windows.sleep(110);
      keybd_event(key, 0, KEYEVENTF_KEYUP, 0);
    end;

  end;
  lua_pop(L, parameters);
end;

function getProcessIDFromProcessName(L: PLua_state): integer; cdecl;
var parameters: integer;
  pname: pchar;
  pid: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    pname:=lua.lua_tostring(L, -1);
    lua_pop(L, parameters);

    pid:=ce_getProcessIDFromProcessName(pname);
    if pid<>0 then
    begin
      lua_pushinteger(L, pid);
      result:=1;
    end;


  end else lua_pop(L, parameters);
end;

function openProcess(L: PLua_state): integer; cdecl;
var parameters: integer;
  pname: pchar;
  pid: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L,-1) then
    begin
      pname:=lua.lua_tostring(L,-1);
      pid:=ce_getProcessIDFromProcessName(pname);
    end
    else
      pid:=lua_tointeger(L,-1);

    lua_pop(L, parameters);

    if pid<>0 then
      ce_openProcess(pid);

    if (ProcessHandle<>0) and (processid=pid) then
    begin
      lua_pushboolean(L, true);
      result:=1;
    end;

  end else lua_pop(L, parameters);
end;

function beep(L: PLua_state): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L)); //clear the stack
  SysUtils.Beep;
  result:=0;
end;

function pause(L: PLua_state): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L)); //clear the stack
  ce_pause;
  result:=0;
end;

function unpause(L: PLua_state): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L)); //clear the stack
  ce_unpause;
  result:=0;
end;


function debugProcess(L: PLua_state): integer; cdecl;
var parameters: integer;
  debuggerinterface: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
    debuggerinterface:=lua_tointeger(L, -1)
  else
    debuggerinterface:=0;

  lua_pop(L, lua_gettop(L)); //clear the stack

  ce_debugProcess(debuggerinterface);
end;

function debug_getBreakpointList(L: Plua_State): integer; cdecl;
var
  al: TAddressArray;
  t: integer;
  i: integer;
begin
  result:=0;
  if debuggerthread<>nil then
  begin
    debuggerthread.getBreakpointAddresses(al);
    lua_newtable(L);
    t:=lua_gettop(L);


    for i:=0 to length(al)-1 do
    begin
      lua_pushinteger(L, i+1);
      lua_pushinteger(L, al[i]);
      lua_settable(L, t);
    end;

    result:=1;
  end;

end;

function lua_checkSynchronize(L: Plua_State): integer; cdecl;
begin
  result:=0;
  CheckSynchronize;
end;

function lua_synchronize(L: Plua_State): integer; cdecl;
var lc: TLuaCaller;
  f: integer;
  routine: string;
begin
  result:=0;
  lc:=nil;
  if lua_isfunction(L,1) then
  begin
    lua_pushvalue(L, 1);
    f:=luaL_ref(L,LUA_REGISTRYINDEX);

    lc:=TLuaCaller.create;
    lc.luaroutineIndex:=f;
  end
  else
  if lua_isstring(L,1) then
  begin
    routine:=lua_tostring(L,1);
    lc:=TLuaCaller.create;
    lc.luaroutine:=routine;
  end;

  if lc<>nil then
  begin
    lc.syncvm:=l;
    if lua_gettop(L)>=2 then
    begin
      lc.synchronizeparam:=2;
      lc.synchronizeparamcount:=lua_gettop(l)-1;
    end
    else
      lc.synchronizeparam:=0;

    tthread.Synchronize(nil, lc.synchronize);

    lc.free;

    result:=1;
  end;
end;

function inMainThread(L: Plua_State): integer; cdecl;
begin
  lua_pushboolean(L, MainThreadID=GetCurrentThreadId);
  result:=1;
end;

function debug_isDebugging(L: Plua_State): integer; cdecl;
begin
  lua_pushboolean(L, debuggerthread<>nil);
  result:=1;
end;

function debug_canBreak(L: Plua_State): integer; cdecl;
var list: TAddressArray;
begin
  if debuggerthread<>nil then
  begin
    debuggerthread.getBreakpointAddresses(list);

    lua_pushboolean(L, (length(list)>0) or ((debuggerthread.CurrentThread<>nil) and (debuggerthread.CurrentThread.isHandled)) );
  end
  else
    lua_pushboolean(L, false);

  result:=1;
end;

function debug_setBreakpoint(L: Plua_State): integer; cdecl;
var parameters: integer;
  address: ptruint;
  size: integer;
  trigger: TBreakpointTrigger;
  method: TBreakpointMethod;

  lc: TLuaCaller;
begin
  lc:=nil;

  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    if parameters>=1 then
    begin
      if lua_isstring(L, 1) then
        address:=symhandler.getAddressFromNameL(lua_tostring(L, 1))
      else
        address:=lua_tointeger(L, 1);
    end else raise exception.create('debug_setBreakpoint needs at least an address');

    if parameters>=2 then
    begin
      if lua_isfunction(L,2) then //address, function type
      begin
        lua_pushvalue(L,2);
        lc:=TLuaCaller.create;
        lc.luaroutineIndex:=luaL_ref(L,LUA_REGISTRYINDEX);
      end
      else
      begin
        if lua_isnumber(L, 2) then
          size:=lua_tointeger(L, 2)
        else
        begin //function name as string
          lc:=TLuaCaller.create;
          lc.luaroutine:=Lua_ToString(L,2);
        end;
      end;
    end
    else
      size:=1;


    if lc=nil then  //address, size OPTIONAL, trigger OPTIONAL, functiontocall OPTIONAL
    begin
      if parameters>=3 then
        trigger:=TBreakpointTrigger(lua_tointeger(L,3))
      else
        trigger:=bptExecute;

      if parameters>=4 then
        method:=TBreakpointMethod(lua_tointeger(L,4))
      else
        method:=bpmDebugRegister;

      if parameters>=5 then
      begin
        if lua_isfunction(L,5) then //address, function type
        begin
          lua_pushvalue(L,5);
          lc:=TLuaCaller.create;
          lc.luaroutineIndex:=luaL_ref(L,LUA_REGISTRYINDEX);
        end
        else
        begin
          lc:=TLuaCaller.create;
          lc.luaroutine:=Lua_ToString(L,5);
        end;

      end;
    end;

    try

      if startdebuggerifneeded(false) then
      begin
        case trigger of
          bptAccess: debuggerthread.SetOnAccessBreakpoint(address, size, method, 0, TBreakpointEvent(lc.BreakpointEvent));
          bptWrite: debuggerthread.SetOnWriteBreakpoint(address, size, method, 0, TBreakpointEvent(lc.BreakpointEvent));
          bptExecute: debuggerthread.SetOnExecuteBreakpoint(address, method,false, 0, TBreakpointEvent(lc.BreakpointEvent));
        end;

        MemoryBrowser.hexview.update;
        Memorybrowser.disassemblerview.Update;
      end;

    except
    end;
  end;

  lua_pop(L, lua_gettop(L)); //clear the stack
end;

function debug_removeBreakpoint(L: Plua_State): integer; cdecl;
var parameters: integer;
  address: ptruint;
  e: boolean;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -1) then
    begin
      e:=false;
      address:=symhandler.getAddressFromNameL(lua_tostring(L, -1));
      if e then //unrecognizable address
      begin
        lua_pop(L, lua_gettop(L));
        exit;
      end;
    end
    else
      address:=lua_tointeger(L, -1);

    ce_debug_removeBreakpoint(address);
  end;

  lua_pop(L, lua_gettop(L)); //clear the stack
end;

function debug_continueFromBreakpoint(L: Plua_State): integer; cdecl;
var parameters: integer;
  method: TContinueOption;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    method:=TContinueOption(lua_tointeger(L, -1));
    ce_debug_continuefrombreakpoint(method);
  end;

  lua_pop(L, lua_gettop(L)); //clear the stack
end;

var isclosing: boolean;
function closeCE(L: Plua_state): integer; cdecl;
var th: thandle;
  b: boolean;
begin
  if isclosing=false then
  begin
    isclosing:=true;

    ce_closeCE; //cleanup

    ExitProcess(0);
  end;
  result:=0;
end;

function hideAllCEWindows(L: Plua_State): integer; cdecl;
begin
  result:=0;
  lua_pop(L, lua_gettop(L)); //clear the stack

  ce_hideAllCEWindows;
end;

function unhideMainCEwindow(L: Plua_State): integer; cdecl;
begin
  result:=0;
  lua_pop(L, lua_gettop(L)); //clear the stack

  ce_unhideMainCEwindow;
end;




function createLabel(L: Plua_State): integer; cdecl;
var parameters: integer;
  f,p: pointer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    f:=lua_toceuserdata(L, -1);
    p:=ce_createLabel(f);

    lua_pop(L, lua_gettop(L));

    luaclass_newClass(L, p);
    result:=1;
  end else lua_pop(L, lua_gettop(L));
end;














function messageDialog(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  message: pchar;
  dialogtype: integer;
  buttontype: integer;

  r: integer;

  i: integer;
  b: TMsgDlgButtons;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=3 then
  begin
    message:=lua.lua_tostring(L,-parameters);
    dialogtype:=lua_tointeger(L,-parameters+1);
    b:=[];
    for i:=-parameters+2 to -1 do
    begin
      buttontype:=lua_tointeger(L,i);
      case buttontype of
        0:  b:=b+[mbYes];
        1:  b:=b+[mbNo];
        2:  b:=b+[mbOK];
        3:  b:=b+[mbCancel];
        4:  b:=b+[mbAbort];
        5:  b:=b+[mbRetry];
        6:  b:=b+[mbIgnore];
        7:  b:=b+[mbAll];
        8:  b:=b+[mbNoToAll];
        9:  b:=b+[mbYesToAll];
        10: b:=b+[mbHelp];
        11: b:=b+[mbClose];
        else b:=b+[mbyes];
      end;
    end;
    lua_pop(L, parameters);

    r:=ce_messageDialog_lua(message, dialogtype, b);
    lua_pushinteger(L,r);
    result:=1;

  end else lua_pop(L, parameters);
end;

function speedhack_setSpeed(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  speed: single;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    speed:=lua_tonumber(L,-1);
    ce_speedhack_setSpeed(speed);
  end;
  lua_pop(L, parameters);
end;

function injectDLL(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  filename: pchar;
  r: boolean;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    filename:=lua.lua_tostring(L,-1);
    r:=false;
    try
      r:=ce_InjectDLL(filename,pchar(''));
    except
    end;

    result:=1;
    lua_pushboolean(L, r);
  end;
  lua_pop(L, parameters);
end;




function getAutoAttachList(L: Plua_State): integer; cdecl;
var f: pointer;
  parameters: integer;
  visible: boolean;
begin
  result:=1;
  lua_pop(L, lua_gettop(L));

  f:=ce_getAutoAttachList();
  luaclass_newClass(L, f);
  result:=1;
end;



function generateAPIHookScript_lua(L: PLua_state): integer; cdecl;
var
  parameters: integer;
  address: string;
  addressTo: string;
  addresstogetnewcalladdress: string;
  script: tstringlist;
begin
  address:='';
  addressTo:='';
  addresstogetnewcalladdress:='';

  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=2 then
  begin
    address:=lua_tostring(L, -parameters);
    addressTo:=lua_tostring(L, (-parameters)+1);

    if parameters=3 then
      addresstogetnewcalladdress:=lua_tostring(L, (-parameters)+2);

    lua_pop(L, lua_gettop(L));

    script:=tstringlist.create;
    try
      generateAPIHookScript(script, address, addressto, addresstogetnewcalladdress);
      lua_pushstring(L, pchar(script.text));
      result:=1;
    finally
      script.free;
    end;
  end;

end;

function createProcess(L: PLua_state): integer; cdecl;
var parameters: integer;
  path,params: string;
  debug: boolean;
  breakonentrypoint: boolean;
begin
  result:=0;
  parameters:=lua_gettop(L);
  path:='';
  params:='';
  debug:=false;
  breakonentrypoint:=false;

  if parameters>0 then
    path:=lua_tostring(L, 1);

  if parameters>1 then
    params:=lua_tostring(L, 2);

  if parameters>2 then
    debug:=lua_toboolean(L, 3);

  if parameters>3 then
    breakonentrypoint:=lua_toboolean(L, 4);

  if path<>'' then
    ce_createProcess(pchar(path), pchar(params), debug, breakonentrypoint);

  lua_pop(L, lua_gettop(L));
end;

function AOBScan(L: PLua_state): integer; cdecl;
var
  parameters: integer;
  i,b: integer;
  scanstring: string;
  protectionflags: string;
  alignmentparam: string;
  alignmenttype: TFastScanMethod;
  list: tstringlist;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters=0 then exit;

  protectionflags:='';
  alignmenttype:=fsmNotAligned;
  alignmentparam:='1';

  if (parameters>=1) and (lua_isstring(L,-parameters)) then
  begin
    //it's a scanstring, optional call
    scanstring:=Lua_ToString(L, -parameters);
    if parameters>=2 then
      protectionflags:=Lua_ToString(L, -parameters+1);

    if parameters>=3 then
      alignmenttype:=TFastScanMethod(lua_tointeger(L, -parameters+2));


    if parameters>=4 then
      alignmentparam:=Lua_ToString(L, -parameters+3);


  end
  else
  begin
    //buildup the scanstring
    scanstring:='';
    for i:=-parameters to -1 do
    begin
      b:=lua_tointeger(L,i);

      if (b>255) then scanstring:=scanstring+'* '
      else
      if b=0 then
      begin
        if not lua_isnumber(L,i) then
          scanstring:=scanstring+'* '
        else
          scanstring:=scanstring+'00 '
      end
      else scanstring:=scanstring+inttohex(b,2)+' ';
    end;
  end;
  lua_pop(L, lua_gettop(L));


  list:=tstringlist.create;
  if getaoblist(scanstring, list, protectionflags, alignmenttype, alignmentparam) then
  begin
    result:=1;
    luaclass_newClass(L, list);
  end
  else
  begin
    list.free;
  end;

end;




function getOpenedProcessID(L: PLua_state): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  result:=1;
  lua_pushinteger(L, processid);
end;

function getSymbolInfo(L: PLua_state): integer; cdecl;
var
  parameters: integer;
  symbolname: string;
  mi: TModuleInfo;

  si: TCESymbolInfo;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    symbolname:=Lua_ToString(L, 1);
    lua_pop(L, lua_gettop(l));

    if symhandler.GetSymbolInfo(symbolname, si) then
    begin
      pushSymbol(L, @si);
      result:=1;
    end;
  end;
end;

function getModuleSize(L: PLua_state): integer; cdecl;
var
  parameters: integer;
  modulename: string;
  mi: TModuleInfo;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    modulename:=Lua_ToString(L, 1);
    lua_pop(L, lua_gettop(l));

    if symhandler.getmodulebyname(modulename, mi) then
    begin
      lua_pushinteger(L, mi.basesize);
      result:=1;
    end;
  end;
end;

function getAddress(L: PLua_state): integer; cdecl;
var parameters: integer;
  s: string;

  local: boolean;

begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    s:=Lua_ToString(L, 1);

    if parameters>=2 then
      local:=lua_toboolean(L, 2)
    else
      local:=false;


    lua_pop(L, lua_gettop(l));


    if not local then
      lua_pushinteger(L,symhandler.getAddressFromNameL(s))
    else
      lua_pushinteger(L,selfsymhandler.getAddressFromNameL(s));

    result:=1;
  end
  else
  lua_pop(L, lua_gettop(l));

end;

function getNameFromAddress(L: PLua_state): integer; cdecl;
var parameters: integer;
  s: string;
  address: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
    else
      address:=lua_tointeger(L,-1);

    lua_pop(L, lua_gettop(l));

    lua_pushstring(L,symhandler.getNameFromAddress(address, true, true));
    result:=1;
  end
  else lua_pop(L, lua_gettop(l));
end;

function inModule(L: PLua_state): integer; cdecl;
var parameters: integer;
  s: string;
  address: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
    else
      address:=lua_tointeger(L,-1);

    lua_pop(L, lua_gettop(l));

    lua_pushboolean(L,symhandler.inModule(address));
    result:=1;
  end
  else lua_pop(L, lua_gettop(l));
end;

function inSystemModule(L: PLua_state): integer; cdecl;
var parameters: integer;
  s: string;
  address: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
    else
      address:=lua_tointeger(L,-1);

    lua_pop(L, lua_gettop(l));

    lua_pushboolean(L,symhandler.inSystemModule(address));
    result:=1;
  end;
end;

function getCommonModuleList(L: PLua_state): integer; cdecl;
begin
  result:=0;
  lua_pop(L, lua_gettop(l));

  luaclass_newClass(L,symhandler.getCommonModuleList);
  result:=1;
end;

function reinitializeDotNetSymbolhandler(L:PLua_state): integer; cdecl;
var modulename: string;
begin
  result:=0;
  if lua_gettop(L)>=1 then
    modulename:=Lua_ToString(L, 1)
  else
    modulename:='';

  symhandler.reinitializeDotNetSymbols(modulename);
end;

function reinitializeSymbolhandler(L: PLua_state): integer; cdecl;
var waittilldone: boolean;
begin
  if lua_gettop(L)>=1 then
    waittilldone:=lua_toboolean(L,1)
  else
    waittilldone:=true;

  lua_pop(L, lua_gettop(L));
  result:=0;


  symhandler.reinitialize(true);

  if waitTillDone then
    symhandler.waitforsymbolsloaded;

end;

function enumModules(L:PLua_state): integer; cdecl;
var
  i: integer;
  ml: tstringlist;
  tableindex: integer;
  entryindex: integer;

  ths: THandle;
  me32: TModuleEntry32;

  is64bitmodule: boolean;

  pid: integer;
begin
  result:=0;

  if lua_gettop(L)=1 then
    pid:=lua_tointeger(L,1)
  else
    pid:=processid;

  ths:=CreateToolhelp32Snapshot(TH32CS_SNAPMODULE or TH32CS_SNAPMODULE32, pid);
  if ths<>0 then
  begin
    lua_newtable(L);
    tableindex:=lua_gettop(L);

    me32.dwSize:=sizeof(MODULEENTRY32);

    i:=1;
    if module32first(ths,me32) then
    repeat
      lua_newtable(L);
      entryindex:=lua_gettop(L);

      lua_pushstring(L, 'Name');
      lua_pushstring(L, extractfilename(me32.szExePath));
      lua_settable(L, entryindex);

      lua_pushstring(L, 'Address');
      lua_pushinteger(L, ptruint(me32.modBaseAddr));
      lua_settable(L, entryindex);


      if (processhandler.isNetwork) or (peinfo_is64bitfile(me32.szExePath, is64bitmodule)=false) then
        is64bitmodule:=processhandler.is64Bit; //fallback on an assumption

      lua_pushstring(L, 'Is64Bit');
      lua_pushboolean(L, is64bitmodule);
      lua_settable(L, entryindex);

      lua_pushstring(L, 'PathToFile');
      lua_pushstring(L, me32.szExePath);
      lua_settable(L, entryindex);


      lua_pushinteger(L, i);
      lua_pushvalue(L, entryindex);
      lua_settable(L, tableindex);

      lua_pop(L, 1); //remove the current entry table

      inc(i);
    until Module32Next(ths, me32)=false;

    lua_pushvalue(L, tableindex); //shouldn't be needed, but let's make sure
    result:=1;

    closehandle(ths);

  end;
end;




function getSettingsForm(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, formSettings);
end;

function getMemoryViewForm(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, MemoryBrowser);
end;


function getMainForm(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, mainform);
end;




function getAddressList(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, mainform.addresslist);
end;

function getFreezeTimer(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, mainform.FreezeTimer);
end;

function getUpdateTimer(L: PLua_state): integer; cdecl;
begin
  result:=1;
  lua_pop(L, lua_gettop(l));
  luaclass_newClass(l, mainform.UpdateTimer);
end;

function setGlobalKeyPollInterval(L: PLua_state): integer; cdecl;
begin
  if lua_gettop(L)=1 then
    hotkeyPollInterval:=lua_tointeger(L, -1);

  result:=0;
end;

function setGlobalDelayBetweenHotkeyActivation(L: PLua_state): integer; cdecl;
begin
  if lua_gettop(L)=1 then
    hotkeyIdletime:=lua_tointeger(L, -1);

  result:=0;
end;



function inheritsFromObject(L: PLua_state): integer; cdecl;
var x: TObject;
begin
  result:=0;
  if lua_gettop(L)>1 then
  begin
    x:=lua_toceuserdata(L, -1);
    lua_pop(L, lua_gettop(l));

    if x<>nil then
    begin
      result:=1;
      lua_pushboolean(l, (x is TObject));
    end;

  end;
end;

function inheritsFromComponent(L: PLua_state): integer; cdecl;
var x: TObject;
begin
  result:=0;
  if lua_gettop(L)>1 then
  begin
    x:=lua_toceuserdata(L, -1);
    lua_pop(L, lua_gettop(l));

    if x<>nil then
    begin
      result:=1;
      lua_pushboolean(l, (x is TComponent));
    end;

  end;
end;

function inheritsFromControl(L: PLua_state): integer; cdecl;
var x: TObject;
begin
  result:=0;
  if lua_gettop(L)>1 then
  begin
    x:=lua_toceuserdata(L, -1);
    lua_pop(L, lua_gettop(l));

    if x<>nil then
    begin
      result:=1;
      lua_pushboolean(l, (x is TControl));
    end;

  end;
end;

function inheritsFromWinControl(L: PLua_state): integer; cdecl;
var x: TObject;
begin
  result:=0;
  if lua_gettop(L)>1 then
  begin
    x:=lua_toceuserdata(L, -1);
    lua_pop(L, lua_gettop(l));

    if x<>nil then
    begin
      result:=1;
      lua_pushboolean(l, (x is TWinControl));
    end;

  end;
end;












function createToggleBox(L: Plua_State): integer; cdecl;
var
  ToggleBox: TCEToggleBox;
  parameters: integer;
  owner: TWincontrol;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    owner:=lua_toceuserdata(L, -parameters)
  else
    owner:=nil;

  lua_pop(L, lua_gettop(L));


  ToggleBox:=TCEToggleBox.Create(owner);
  if owner<>nil then
    ToggleBox.Parent:=owner;

  luaclass_newClass(L, ToggleBox);
  result:=1;
end;


function opendialog_execute(L: Plua_State): integer; cdecl; //6.2- version only
var
  opendialog: TOpenDialog;
begin
  opendialog:=luaclass_getClassObject(L);
  if opendialog.execute then
    lua_pushnil(L)
  else
    lua_pushstring(L, opendialog.FileName);

  result:=1;
end;

function createOpenDialog(L: Plua_State): integer; cdecl;
var
  o: TOpenDialog;
begin
  result:=0;

  if lua_gettop(L)>=1 then
    luaclass_newClass(L, TOpenDialog.create(lua_toceuserdata(L, 1)))
  else
    luaclass_newClass(L, TOpenDialog.create(nil));

  result:=1;
end;

function createSaveDialog(L: Plua_State): integer; cdecl;
var
  o: TSaveDialog;
begin
  result:=0;

  if lua_gettop(L)>=1 then
    luaclass_newClass(L, TSaveDialog.create(lua_toceuserdata(L, 1)))
  else
    luaclass_newClass(L, TSaveDialog.create(nil));

  result:=1;
end;

function CreateSelectDirectoryDialog(L: Plua_State): integer; cdecl;
var
  o: TSaveDialog;
begin
  result:=0;

  if lua_gettop(L)>=1 then
    luaclass_newClass(L, TSelectDirectoryDialog.create(lua_toceuserdata(L, 1)))
  else
    luaclass_newClass(L, TSelectDirectoryDialog.create(nil));

  result:=1;
end;


function createMemoryStream(L: Plua_State): integer; cdecl;
begin
  luaclass_newClass(L, TMemoryStream.create);
  result:=1;
end;

function createFileStream(L: Plua_State): integer; cdecl;
var
  filename: string;
  mode: word;
begin
  result:=0;
  if lua_gettop(L)=2 then
  begin
    filename:=lua_tostring(L, 1);
    mode:=lua_tointeger(L, 2);
    luaclass_newClass(L, TFileStream.create(filename, mode));
    result:=1;
  end;
end;




function readRegionFromFile(L: Plua_State): integer; cdecl;
var parameters: integer;
  filename: string;
  address: ptruint;
  size: integer;
  x: PtrUInt;
  buf: pointer;
  f: tmemorystream;
begin
  result:=0;
  x:=0;
  f:=nil;

  parameters:=lua_gettop(L);
  if (parameters=2) then
  begin
    filename:=Lua_ToString(L, -2);
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-1))
    else
      address:=lua_tointeger(L,-1);

    lua_pop(L, lua_gettop(L));

    f:=tmemorystream.create;
    try
      f.LoadFromFile(filename);
      writeprocessmemory(processhandle, pointer(address), f.memory, f.size, x);

    finally
      freeandnil(f);
    end;


    result:=1;
    lua_pushinteger(L,x);
  end else lua_pop(L, lua_gettop(L));
end;


function writeRegionToFile(L: Plua_State): integer; cdecl;
var parameters: integer;
  filename: string;
  address: ptruint;
  size: integer;
  x: PtrUInt;
  buf: pointer;
  f: tfilestream;
begin
  result:=0;
  x:=0;
  f:=nil;

  parameters:=lua_gettop(L);
  if (parameters=3) then
  begin
    filename:=Lua_ToString(L, -3);
    if lua_isstring(L, -2) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
    else
      address:=lua_tointeger(L,-2);

    size:=lua_tointeger(L,-1);
    lua_pop(L, lua_gettop(L));

    getmem(buf,size);
    try

      readprocessmemory(processhandle, pointer(address), buf, size, x);

      f:=tfilestream.create(filename, fmCreate);
      f.WriteBuffer(buf^, x);

    finally
      if f<>nil then
        FreeAndNil(f);

      freemem(buf);
    end;


    result:=1;
    lua_pushinteger(L,x);
  end else lua_pop(L, lua_gettop(L));
end;


function registerSymbol(L: Plua_State): integer; cdecl;
var parameters: integer;
  symbolname: string;
  address: string;
  donotsave: boolean;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if (parameters>=2) then
  begin
    symbolname:=Lua_ToString(L, -parameters);
    if lua_isstring(L, -parameters+1) then
      address:=lua_tostring(L,-parameters+1)
    else
      address:=IntToHex(lua_tointeger(L,-parameters+1),1);


    donotsave:=(parameters>=3) and (lua_toboolean(L, -parameters+2));


    symhandler.AddUserdefinedSymbol(address, symbolname, donotsave);
  end;

  lua_pop(L, lua_gettop(L));
end;

function unregisterSymbol(L: Plua_State): integer; cdecl;
var parameters: integer;
  symbolname: string;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if (parameters=1) then
  begin
    symbolname:=Lua_ToString(L, -1);
    symhandler.DeleteUserdefinedSymbol(symbolname);
  end;

  lua_pop(L, lua_gettop(L));
end;

function resetLuaState(L: Plua_State): integer; cdecl;
begin
  result:=0;
  lua_pop(L, lua_gettop(L));
  InitializeLua; //this creates a NEW lua state (cut doesn't destroy the current one)
end;

function reloadSettingsFromRegistry(L: Plua_State): integer; cdecl;
begin
  result:=0;
  LoadSettingsFromRegistry;
end;

function createMemScan(L: Plua_State): integer; cdecl;
var
  progressbar: TCustomProgressbar;
  memscan: TMemScan;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
    progressbar:=lua_toceuserdata(L, -1)
  else
    progressbar:=nil;

  lua_pop(L, lua_gettop(L));

  if (progressbar<>nil) and (progressbar is TCustomProgressBar=false) then
    raise exception.create('createMemScan needs a progressbar or nil. '+progressbar.ClassName+' is not a progressbar');

  memscan:=TMemscan.create(progressbar);

  luaclass_newClass(L, memscan);
  result:=1;
end;

function getCurrentMemscan(L: Plua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));

  luaclass_newClass(L, mainform.memscan);
  result:=1;
end;





function supportCheatEngine(L: Plua_State): integer; cdecl;
var
  parameters: integer;
  //attachwindow, hasclosebutton, width, height, position ,yoururl OPTIONAL, extraparameters OPTIONAL, percentageshown OPTIONAL
  attachwindow: TCustomForm;
  hasCloseButton: boolean;
  width: integer;
  height: integer;
  position: integer;
  yoururl: string;
  extraparameters: string;
  percentageshown: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=5 then
  begin
    attachwindow:=lua_toceuserdata(L, 1);
    hasCloseButton:=lua_toboolean(L, 2);
    width:=lua_tointeger(L, 3);
    height:=lua_tointeger(L, 4);
    position:=lua_tointeger(L, 5);

    if parameters>=6 then
      yoururl:=Lua_ToString(L, 6)
    else
      yoururl:='';

    if parameters>=7 then
      extraparameters:=Lua_ToString(L, 7)
    else
      extraparameters:='';

    if parameters>=8 then
      percentageshown:=lua_tointeger(L, 8)
    else
      percentageshown:=0;

    lua_pop(L, lua_gettop(L));

    if adwindow=nil then
      adwindow:=TADWindow.Create2(Application, hasclosebutton);

    adwindow.clientWidth:=width;
    adwindow.clientheight:=height;
    adwindow.show;
    adwindow.AttachToForm(attachwindow);
    case position of
      0: adwindow.setPosition(akTop);
      1: adwindow.setPosition(akRight);
      2: adwindow.setPosition(akBottom);
      3: adwindow.setPosition(akLeft);
    end;

    adwindow.setUserUrl(yoururl);
    adwindow.setUserPercentage(percentageshown);
    adwindow.optional:=extraparameters;

    adwindow.LoadAdNow;


  end else lua_pop(L, lua_gettop(L));
end;

function fuckCheatEngine(L: Plua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  if adwindow<>nil then
    adWindow.visible:=false;

  result:=0;
end;

function dbk_initialize(L: Plua_State): integer; cdecl;
var x: bool;
begin
  LoadDBK32;
  lua_pushboolean(L, isDriverLoaded(@x));
  result:=1;
end;

function dbk_useKernelmodeOpenProcess(L: Plua_State): integer; cdecl;
begin
  UseDBKOpenProcess;

  result:=0;
end;

function dbk_useKernelmodeProcessMemoryAccess(L: Plua_State): integer; cdecl;
begin
  UseDBKReadWriteMemory;
  result:=0;
end;

function dbk_useKernelmodeQueryMemoryRegions(L: Plua_State): integer; cdecl;
begin
  UseDBKQueryMemoryRegion;
  result:=0;
end;

function dbk_getPEProcess(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  pid: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    pid:=lua_tointeger(L,-1);

    lua_pushinteger(L, GetPEProcess(pid));
    result:=1;
  end else lua_pop(L, parameters);
end;

function dbk_getPEThread(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  pid: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    pid:=lua_tointeger(L,-1);

    lua_pushinteger(L, GetPEThread(pid));
    result:=1;
  end else lua_pop(L, parameters);
end;

function dbk_executeKernelMemory(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  address: ptruint;
  parameter: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    if lua_isstring(L, -parameters) then
      address:=symhandler.getAddressFromNameL(Lua_ToString(L,-parameters))
    else
      address:=lua_tointeger(L, -parameters);

    if parameters>=2 then
    begin
      if lua_isstring(L, -parameters+1) then
        parameter:=symhandler.getAddressFromNameL(Lua_ToString(L,-parameters+1))
      else
        parameter:=lua_tointeger(L, -parameters+1);
    end
    else
      parameter:=0;

    lua_pop(L, parameters);


    executeKernelCode(address,parameter);

    result:=0;
  end else lua_pop(L, parameters);
end;

function dbk_readMSR(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  msr: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    msr:=lua_tointeger(L,-1);
    lua_pushinteger(L, readMSR(msr));
    result:=1;
  end else lua_pop(L, parameters);
end;

function dbk_writeMSR(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  msr: dword;
  msrvalue: qword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    msr:=lua_tointeger(L,-2);
    msrvalue:=lua_tointeger(L,-1);
    writemsr(msr, msrvalue);
  end;

  lua_pop(L, parameters);
end;

function createSplitter(L: Plua_State): integer; cdecl;
var
  Splitter: TCESplitter;
  parameters: integer;
  owner: TWincontrol;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    owner:=lua_toceuserdata(L, -parameters)
  else
    owner:=nil;

  lua_pop(L, lua_gettop(L));


  Splitter:=TCESplitter.Create(owner);
  if owner<>nil then
    Splitter.Parent:=owner;

  luaclass_newClass(L, splitter);
  result:=1;
end;

function createPaintBox(L: Plua_State): integer; cdecl;
var
  paintbox: TPaintbox;
  parameters: integer;
  owner: TWincontrol;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    owner:=lua_toceuserdata(L, 1)
  else
    owner:=nil;

  lua_pop(L, lua_gettop(L));


  paintbox:=TPaintBox.Create(owner);
  if owner<>nil then
    paintbox.Parent:=owner;

  luaclass_newClass(L, paintbox);
  result:=1;
end;

function allocateSharedMemory(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  sharedmemoryname: string;
  size: ptruint;
  address: pointer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    sharedmemoryname:=Lua_ToString(L,-parameters);

    if parameters>=2 then
      size:=lua_tointeger(L, -parameters+1)
    else
      size:=4096;

    lua_pop(L, parameters);

    address:=allocateSharedMemoryIntoTargetProcess(sharedmemoryname, size);
    if address<>nil then
    begin
      lua_pushinteger(L, ptruint(address));
      result:=1;
    end;
  end else lua_pop(L, parameters);
end;

function deallocateSharedMemory(L: PLua_State): integer; cdecl;
var parameters: integer;
  address: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
    lua_pop(L, parameters);

  lua_pushstring(L, 'deallocateSharedMemory is not implemented (It''s not even in the list of available functions)');
  lua_error(L);
end;

function getCheatEngineDir(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(l));
  lua_pushstring(L, CheatEngineDir);
  result:=1;
end;

function getInstructionSize(L: PLua_State): integer; cdecl;
var parameters: integer;
  address, address2: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -parameters) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-parameters))
    else
      address:=lua_tointeger(L,-parameters);

    lua_pop(L, parameters);

    address2:=address;
    disassemble(address);
    lua_pushinteger(L, address-address2);
    result:=1;
  end
  else
    lua_pop(L, parameters);
end;

function getPreviousOpcode(L: PLua_State): integer; cdecl;
var parameters: integer;
  address, address2: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -parameters) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-parameters))
    else
      address:=lua_tointeger(L,-parameters);

    lua_pop(L, parameters);

    lua_pushinteger(L, previousopcode(address));
    result:=1;
  end
  else
    lua_pop(L, parameters);
end;

function disassemble_lua(L: PLua_State): integer; cdecl;
var parameters: integer;
  address: ptruint;
  d: TDisassembler;
  x: string;
  s: string;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    if lua_isstring(L, -parameters) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-parameters))
    else
      address:=lua_tointeger(L,-parameters);

    lua_pop(L, parameters);

    d:=TDisassembler.Create;
    try
      d.showmodules:=false;
      d.showsymbols:=false;
      s:=d.disassemble(address, x);
    finally
      d.free;
    end;


    result:=1;
    lua_pushstring(L, s);
  end else lua_pop(L, parameters);
end;

function splitDisassembledString(L: PLua_State): integer; cdecl;
var parameters: integer;
  disassembledstring: string;

  address, bytes, opcode, special: string;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    disassembledstring:=lua_tostring(L,-parameters);
    lua_pop(L, parameters);

    disassembler.splitDisassembledString(disassembledstring, true, address, bytes, opcode, special);

    result:=4;
    lua_pushstring(L, special);
    lua_pushstring(L, opcode);
    lua_pushstring(L, bytes);
    lua_pushstring(L, address);
  end
  else
    lua_pop(L, parameters);
end;

function hexadecimalview_getTopAddress(L: PLua_State): integer; cdecl;
var
  hv: THexView;
begin
  hv:=luaclass_getClassObject(L);
  lua_pushinteger(L, hv.address);
  result:=1;
end;

function hexadecimalview_setTopAddress(L: PLua_State): integer; cdecl;
var
  hv: THexView;
  address: ptruint;
begin
  result:=0;
  hv:=luaclass_getClassObject(L);
  if lua_gettop(L)>=1 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(Lua_ToString(L, -1))
    else
      address:=lua_tointeger(L, -1);

    hv.address:=address;
  end
end;

function hexadecimalview_onAddressChange(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  hexadecimalview: THexView;
  f: integer;
  routine: string;

  lc: TLuaCaller;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    hexadecimalview:=lua_toceuserdata(L,-2);

    CleanupLuaCall(tmethod(hexadecimalview.onAddressChange));
    hexadecimalview.onAddressChange:=nil;

    if lua_isfunction(L,-1) then
    begin
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      hexadecimalview.onAddressChange:=lc.AddressChangeEvent;
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      hexadecimalview.onAddressChange:=lc.AddressChangeEvent;
    end;

  end;

  lua_pop(L, parameters);
end;

function hexadecimalview_onByteSelect(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  hexadecimalview: THexView;
  f: integer;
  routine: string;

  lc: TLuaCaller;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    hexadecimalview:=lua_toceuserdata(L,-2);

    CleanupLuaCall(tmethod(hexadecimalview.onByteSelect));
    hexadecimalview.onByteSelect:=nil;

    if lua_isfunction(L,-1) then
    begin
      routine:=Lua_ToString(L,-1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      hexadecimalview.onByteSelect:=lc.ByteSelectEvent;
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      hexadecimalview.onByteSelect:=lc.ByteSelectEvent;
    end;

  end;

  lua_pop(L, parameters);
end;


function disassemblerview_getSelectedAddress(L: PLua_State): integer; cdecl;    //6.2-
var
  dv: TDisassemblerview;
begin
  dv:=luaclass_getClassObject(L);
  result:=2;
  lua_pushinteger(L, dv.SelectedAddress);
  lua_pushinteger(L, dv.SelectedAddress2); //6.2: Returns both addresses
end;

function disassemblerview_setSelectedAddress(L: PLua_State): integer; cdecl;  //6.2-
var
  dv: TDisassemblerview;
  address: ptruint;
begin
  result:=0;
  dv:=luaclass_getClassObject(L);
  if lua_gettop(L)>=1 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(Lua_ToString(L, -1))
    else
      address:=lua_tointeger(L, -1);

    dv.SelectedAddress:=address;
  end;
end;

function disassemblerview_onSelectionChange(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  disassemblerview: TDisassemblerview;
  f: integer;
  routine: string;

  lc: TLuaCaller;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    disassemblerview:=lua_toceuserdata(L,-2);

    CleanupLuaCall(tmethod(disassemblerview.onselectionchange));
    disassemblerview.onselectionchange:=nil;

    if lua_isfunction(L,-1) then
    begin
      routine:=Lua_ToString(L,-1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      disassemblerview.onselectionchange:=lc.DisassemblerSelectionChangeEvent;
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      disassemblerview.onselectionchange:=lc.DisassemblerSelectionChangeEvent;
    end;
    lua_pop(L, lua_gettop(L));
  end;

  lua_pop(L, parameters);
end;

function getForegroundProcess(L: PLua_State): integer; cdecl;
var h: thandle;
  pid: dword;
begin
  lua_pop(L, lua_gettop(L));

  h:=GetForegroundWindow;

  GetWindowThreadProcessId(h, pid);
  lua_pushinteger(L, pid);
  result:=1;
end;

function cheatEngineIs64Bit(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  lua_pushboolean(L, {$ifdef cpu64}true{$else}false{$endif});
  result:=1;
end;

function targetIs64Bit(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  lua_pushboolean(L, processhandler.is64Bit);
  result:=1;
end;

function unregisterFormAddNotification(L: PLua_State): integer; cdecl;
var lc: TLuacaller;
begin
  result:=0;
  if lua_gettop(L)=1 then
  begin
    lc:=lua_ToCEUserData(L, -1);
    if lc<>nil then
      screen.RemoveHandlerFormAdded(lc.ScreenFormEvent);
  end;
end;

function registerFormAddNotification(L: PLua_State): integer; cdecl;
var lc: TLuaCaller;
  f: integer;
  routine: string;
begin
  result:=0;
  if lua_gettop(L)=1 then
  begin
    lc:=nil;

    if lua_isfunction(L,-1) then
    begin
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      screen.AddHandlerFormAdded(lc.ScreenFormEvent);
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      screen.AddHandlerFormAdded(lc.ScreenFormEvent);
    end;


    luaclass_newClass(L, lc);
    result:=1;
  end;
end;

function getFormCount(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  lua_pushinteger(L, screen.FormCount);
  result:=1;
end;

function getForm(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  f: TCustomForm;
  index: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    index:=lua_tointeger(L, -1);
    lua_pop(L, lua_gettop(L));

    if index<screen.formcount then
    begin
      luaclass_newClass(L, screen.Forms[index]);
      result:=1;
    end;
  end
  else
    lua_pop(L, lua_gettop(L));
end;

function onAutoGuess(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  lc: TLuaCaller;
  routine: string;
  f: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    CleanupLuaCall(tmethod(onAutoGuessRoutine));
    onAutoGuessRoutine:=nil;

    if lua_isfunction(L,-1) then
    begin
      f:=luaL_ref(L,LUA_REGISTRYINDEX); //pop the last item of the stack, which is what I need

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      onAutoGuessRoutine:=lc.AutoGuessEvent;
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=Lua_ToString(L, -1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      onAutoGuessRoutine:=lc.AutoGuessEvent;
    end;


  end;

  lua_pop(L, lua_gettop(L));
end;

function onAPIPointerChange(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  lc: TLuaCaller;
  routine: string;
  f: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    CleanupLuaCall(tmethod(plugin.onAPIPointerChange));
    plugin.onAPIPointerChange:=nil;

    if lua_isfunction(L,-1) then
    begin
      f:=luaL_ref(L,LUA_REGISTRYINDEX); //pop the last item of the stack, which is what I need

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
      plugin.onAPIPointerChange:=lc.NotifyEvent;
    end
    else
    if lua_isstring(L,-1) then
    begin
      routine:=Lua_ToString(L, -1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
      plugin.onAPIPointerChange:=lc.NotifyEvent;
    end;


  end;

  lua_pop(L, lua_gettop(L));
end;

function setAPIPointer(L: PLua_State): integer; cdecl;
var parameters: integer;
  apiID: integer;
  address: ptruint;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    apiID:=lua_tointeger(L, -2);
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(Lua_ToString(L, -1))
    else
      address:=lua_tointeger(L, -1);


    lua_pop(L, parameters);

    case apiid of
      0: newkernelhandler.OpenProcess:=pointer(address);
      1: newkernelhandler.ReadProcessMemory:=pointer(address);
      2: newkernelhandler.WriteProcessMemory:=pointer(address);
      3: newkernelhandler.VirtualQueryEx:=pointer(address);
    end;

  end
  else
    lua_pop(L, parameters);
end;


function dbvm_initialize(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  offload: boolean;
begin
  //for now use the default
  if (dbvm_version>0) then
  begin
    //already loaded and initialized
    lua_pop(L, lua_gettop(L));
    lua_pushboolean(L, true);
    result:=1;
    exit;
  end;

  //not yet loaded/initialized
  if (vmx_password1=0) and (vmx_password2=0) then
  begin
    vmx_password1:=$76543210;
    vmx_password2:=$fedcba98;
  end;



  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    offload:=lua_toboolean(L, -1);
    lua_pop(L, lua_gettop(L));

    if offload then
    begin
      if (dbvm_version=0) then
      begin
        //not yet loaded.
        if isDBVMCapable then
        begin
          LoadDBK32;
          launchdbvm;
        end;
      end;
    end;
  end
  else
    lua_pop(L, lua_gettop(L));

  result:=1;
  lua_pushboolean(L, dbvm_version>0);
end;

function shellExecute(L: PLua_State): integer; cdecl;
var
  pcount: integer;
  command: string;
  parameters: string;
  folder: string;
  showcommand: integer;
begin
  pcount:=lua_gettop(L);
  if pcount>=1 then
  begin
    command:=utf8toansi(lua_tostring(L, -pcount));

    if pcount>=2 then
      parameters:=utf8toansi(lua_tostring(L, -pcount+1))
    else
      parameters:='';


    if pcount>=3 then
      folder:=utf8toansi(lua_tostring(L, -pcount+2))
    else
      folder:='';

    if pcount>=4 then
      showcommand:=lua_tointeger(L, -pcount+3)
    else
      showcommand:=SW_NORMAL;

    shellapi.shellexecute(0,'open',pchar(command),pchar(parameters),pchar(folder),showcommand);
  end;

  lua_pop(L, lua_gettop(L));

  result:=0;

end;

function getTickCount_lua(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  result:=1;
  lua_pushinteger(L, GetTickCount);
end;

function processMessages(L: PLua_State): integer; cdecl;
begin
  lua_pop(L, lua_gettop(L));
  result:=0;
  application.ProcessMessages;
end;

function integerToUserData(L: PLua_State): integer; cdecl;
var
  i: integer;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    i:=lua_tointeger(L,-1);
    lua_pop(L, parameters);

    luaclass_newClass(L, pointer(ptruint(i)));
    result:=1;

  end else lua_pop(L, parameters);
end;

function userDataToInteger(L: PLua_State): integer; cdecl;
var
  u: pointer;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    u:=lua_toceuserdata(L,-1);
    lua_pop(L, parameters);

    lua_pushinteger(L, ptruint(u));
    result:=1;

  end else lua_pop(L, parameters);
end;

function writeToClipboard(L: PLua_State): integer; cdecl;
var
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
    Clipboard.AsText:=Lua_ToString(L, -1);


  lua_pop(L, parameters);
end;

function readFromClipboard(L: PLua_State): integer; cdecl;
var s: string;
begin
  lua_pop(L, lua_gettop(L));

  lua_pushstring(L, Clipboard.AsText);
  result:=1;
end;




function createBitmap(L: Plua_State): integer; cdecl;
var
  Bitmap: TBitmap;
  parameters: integer;
  width, height: integer;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    width:=lua_tointeger(L, 1)
  else
    width:=screen.width;

  if parameters>=2 then
    height:=lua_tointeger(L, 2)
  else
    height:=screen.height;


  lua_pop(L, parameters);

  Bitmap:=TBitmap.Create;
  bitmap.Width:=width;
  bitmap.Height:=height;


  luaclass_newClass(L, Bitmap);
  result:=1;
end;

function createPNG(L: Plua_State): integer; cdecl;
var
  png: TPortableNetworkGraphic;
  parameters: integer;
  width, height: integer;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    width:=lua_tointeger(L, 1)
  else
    width:=screen.width;

  if parameters>=2 then
    height:=lua_tointeger(L, 2)
  else
    height:=screen.height;


  lua_pop(L, parameters);

  png:=TPortableNetworkGraphic.Create;
  png.Width:=width;
  png.Height:=height;


  luaclass_newClass(L, Png);
  result:=1;
end;

function createJpeg(L: Plua_State): integer; cdecl;
var
  jpeg: TJPEGImage;
  parameters: integer;
  width, height: integer;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    width:=lua_tointeger(L, 1)
  else
    width:=screen.width;

  if parameters>=2 then
    height:=lua_tointeger(L, 2)
  else
    height:=screen.height;


  lua_pop(L, parameters);

  jpeg:=TJPEGImage.Create;
  jpeg.Width:=width;
  jpeg.Height:=height;


  luaclass_newClass(L, jpeg);
  result:=1;
end;


function errorOnLookupFailure(L: Plua_State): integer; cdecl;
var
  parameters: integer;

  oldvalue: boolean;
begin
  result:=0;
  parameters:=lua_gettop(L);
  oldvalue:=symhandler.ExceptionOnLuaLookup;

  if parameters=1 then
  begin
    symhandler.ExceptionOnLuaLookup:=lua_toboolean(L, -1);
    lua_pop(L, parameters);
    lua_pushboolean(L, oldvalue);
    result:=1;
  end
  else
    lua_pop(L, parameters);


end;

function loadPlugin(L: PLua_State): integer; cdecl;
var
  p: string;
  parameters: integer;
  pluginid: integer;
begin
  result:=1;
  pluginid:=0;

  parameters:=lua_gettop(L);

  if parameters=1 then
  begin
    p:=Lua_ToString(L, -1);
    try

      pluginid:=pluginhandler.LoadPlugin(p);
      if pluginid<>-1 then
        pluginhandler.EnablePlugin(pluginid);
    except
      pluginid:=-1;
    end;

  end;

  lua_pop(L, parameters);

  if pluginid=-1 then
    lua_pushnil(L)
  else
    lua_pushinteger(L, pluginid);
end;

function getCEVersion(L: PLua_State): integer; cdecl;
var
  p: string;
  parameters: integer;
  pluginid: integer;
begin
  lua_pop(L, lua_gettop(L));

  result:=1;
  lua_pushnumber(L, ceversion);
end;

function lua_Utf8ToAnsi(L: Plua_State): integer; cdecl;
var
  s: string;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);

  if parameters=1 then
  begin
    s:=Lua_ToString(L, -1);
    lua_pop(L, parameters);

    lua_pushstring(L, Utf8ToAnsi(s));
    result:=1;
  end
  else
    lua_pop(L, parameters);
end;

function lua_AnsitoUTF8(L: Plua_State): integer; cdecl;
var
  s: string;
  parameters: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);

  if parameters=1 then
  begin
    s:=Lua_ToString(L, -1);
    lua_pop(L, parameters);

    lua_pushstring(L, AnsiToUtf8(s));
    result:=1;
  end
  else
    lua_pop(L, parameters);
end;


function fullAccess(L: PLua_state): integer; cdecl;
var parameters: integer;
  address: ptruint;
  size: integer;
  op: dword;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=2 then
  begin
    if lua_isstring(L, -1) then
      address:=symhandler.getAddressFromNameL(lua_tostring(L,-2))
    else
      address:=lua_tointeger(L,-2);

    size:=lua_tointeger(L,-1);

    lua_pop(L, lua_gettop(l));

    virtualprotectex(processhandle,pointer(address),size,PAGE_EXECUTE_READWRITE,op);
  end;
end;


function getProcesslist_lua(L: PLua_state): integer; cdecl;
var
  parameters: integer;
  s: tstrings;
  i: integer;
  pid: integer;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    s:=lua_toceuserdata(L,1);
    lua_pop(L, lua_gettop(l));
    if (s<>nil) and (s is TStrings) then
      GetProcessList(s, false, true)
    else
    begin
      lua_pushstring(L,'getProcessList: the provided List object is not valid');
      lua_error(L);
    end;
  end
  else
  begin
    //table version
    s:=tstringlist.create;
    GetProcessList(s, false, true);

    lua_newtable(L);

    for i:=0 to s.Count-1 do
    begin
      if TryStrToInt(copy(s[i],1,8), pid) then
      begin
        lua_pushinteger(L, pid);
        lua_pushstring(L, copy(s[i], 10, length(s[i])));
        lua_settable(L, 1);
      end;
    end;
    s.free;

    result:=1; //table
  end;
end;

function getThreadlist_lua(L: PLua_state): integer; cdecl;
var parameters: integer;
  s: tstrings;
begin
  result:=0;
  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    s:=lua_toceuserdata(L,1);
    lua_pop(L, lua_gettop(l));
    if (s<>nil) and (s is TStrings) then
      GetThreadList(s)
    else
    begin
      lua_pushstring(L,'getThreadlist: the provided List object is not valid');
      lua_error(L);
    end;
  end
  else
    lua_pop(L, lua_gettop(l));
end;

function createTreeView(L: Plua_State): integer; cdecl; //undocument, unsupported, unworking
var
  Treeview: TCETreeView;
  parameters: integer;
  owner: TWincontrol;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
    owner:=lua_toceuserdata(L, 1)
  else
    owner:=nil;

  lua_pop(L, lua_gettop(L));


  Treeview:=TCETreeview.Create(owner);
  if owner<>nil then
    Treeview.Parent:=owner;

  luaclass_newClass(L, Treeview);
  result:=1;
end;

function lua_loadTable(L: Plua_State): integer; cdecl;
var
  filename: string;
  parameters: integer;
  merge: boolean;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    filename:=Lua_ToString(L, 1);
    if parameters>=2 then
      merge:=lua_toboolean(L,2)
    else
      merge:=false;

    loadtable(filename,merge);
  end;

  lua_pop(L, lua_gettop(L));
end;

function lua_saveTable(L: Plua_State): integer; cdecl;
var
  filename: string;
  parameters: integer;
  protect: boolean;
begin
  result:=0;

  parameters:=lua_gettop(L);
  if parameters>=1 then
  begin
    filename:=Lua_ToString(L, 1);
    if parameters>=2 then
      protect:=lua_toboolean(L,2)
    else
      protect:=false;

    savetable(filename, protect);
  end;

  lua_pop(L, lua_gettop(L));
end;

function lua_detachIfPossible(L: Plua_State): integer; cdecl;
begin
  DetachIfPossible;
  lua_pop(L, lua_gettop(L));
end;

function getComment(L: PLua_state): integer; cdecl;
var address: ptruint;
begin
  result:=0;
  if lua_gettop(L)=1 then
  begin
    if lua_type(L,1)=LUA_TSTRING then
      address:=symhandler.getAddressFromName(Lua_ToString(L,1))
    else
      address:=lua_tointeger(L,1);

    lua_pushstring(L, dassemblercomments.comments[address]);
    result:=1;
  end;
end;

function setComment(L: PLua_state): integer; cdecl;
var address: ptruint;
  comment: string;
begin
  result:=0;
  if lua_gettop(L)=2 then
  begin
    if lua_type(L,1)=LUA_TSTRING then
      address:=symhandler.getAddressFromName(Lua_ToString(L,1))
    else
      address:=lua_tointeger(L,1);

    comment:=Lua_ToString(L, 2);

    dassemblercomments.comments[address]:=comment;
  end;
end;

function getHeader(L: PLua_state): integer; cdecl;
var address: ptruint;
begin
  result:=0;
  if lua_gettop(L)=1 then
  begin
    if lua_type(L,1)=LUA_TSTRING then
      address:=symhandler.getAddressFromName(Lua_ToString(L,1))
    else
      address:=lua_tointeger(L,1);

    lua_pushstring(L, dassemblercomments.commentHeader[address]);
    result:=1;
  end;
end;

function setHeader(L: PLua_state): integer; cdecl;
var address: ptruint;
  Header: string;
begin
  result:=0;
  if lua_gettop(L)=2 then
  begin
    if lua_type(L,1)=LUA_TSTRING then
      address:=symhandler.getAddressFromName(Lua_ToString(L,1))
    else
      address:=lua_tointeger(L,1);

    Header:=Lua_ToString(L, 2);

    dassemblercomments.commentHeader[address]:=Header;
  end;
end;

function lua_createClass(L: PLua_State): integer; cdecl;
var classname: string;
begin
  result:=0;
  if lua_gettop(L)=1 then
  begin
    classname:=Lua_ToString(L,1);
    luaclass_newClass(L, GetClass(classname).Create);
    result:=1;
  end;
end;

function openLuaServer(L: PLua_State): integer; cdecl;
var name: string;
begin
  if lua_gettop(L)=1 then
    name:=Lua_ToString(L, 1)
  else
    name:='cheatenginebla';

  if luaserverExists(name)=false then
    tluaserver.create(name);
end;

function lua_registerAutoAssemblerCommand(L: PLua_State): integer; cdecl;
var command: string;
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=2 then
  begin
    if lua_isstring(L, 1) then
    begin
      command:=Lua_ToString(L, 1);

      if lua_isfunction(L,2) then
      begin
        f:=luaL_ref(L,LUA_REGISTRYINDEX);

        lc:=TLuaCaller.create;
        lc.luaroutineIndex:=f;
      end
      else
      if lua_isstring(L,2) then
      begin
        routine:=lua_tostring(L,-1);
        lc:=TLuaCaller.create;
        lc.luaroutine:=routine;
      end
      else exit;

      RegisterAutoAssemblerCommand(command, lc.AutoAssemblerCallback);
    end;

  end;

end;

function lua_unregisterAutoAssemblerCommand(L: PLua_State): integer; cdecl;
var command: string;
begin
  if lua_gettop(L)=1 then
  begin
    command:=Lua_ToString(L, 1);
    UnregisterAutoAssemblerCommand(command);
  end;
end;

function lua_registerSymbolLookupCallback(L: PLua_State): integer; cdecl;
var
  f: integer;
  sltype: TSymbolLookupCallbackPoint;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=2 then
  begin
    if lua_isnumber(L, 2) then sltype:=TSymbolLookupCallbackPoint(lua_tointeger(L, 2)) else exit;
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerSymbolLookupCallback(lc.SymbolLookupCallback, sltype));
    result:=1;
  end;

end;

function lua_unregisterSymbolLookupCallback(L: PLua_State): integer; cdecl;
var id: integer;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterSymbolLookupCallback(lua_tointeger(L, 1));
end;

function lua_registerAddressLookupCallback(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerAddressLookupCallback(lc.AddressLookupCallback));
    result:=1;
  end;

end;

function lua_unregisterAddressLookupCallback(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterAddressLookupCallback(lua_tointeger(L, 1));
end;

function lua_registerGlobalDisassembleOverride(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerGlobalDisassembleOverride(lc.DisassembleEvent));
    result:=1;
  end;

end;

function lua_unregisterGlobalDisassembleOverride(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterGlobalDisassembleOverride(lua_tointeger(L, 1));
end;

function lua_registerStructureDissectOverride(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
  m: Tmethod;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerStructureDissectOverride(lc.StructureDissectEvent));
    result:=1;
  end;
end;

function lua_unregisterStructureDissectOverride(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterStructureDissectOverride(lua_tointeger(L, 1));
end;


function lua_registerStructureNameLookup(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerStructureNameLookup(lc.StructureNameLookup));
    result:=1;
  end;
end;

function lua_unregisterStructureNameLookup(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterStructureNameLookup(lua_tointeger(L, 1));
end;

function lua_registerAssembler(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerAssembler(lc.AssemblerEvent));
    result:=1;
  end;
end;

function lua_unregisterAssembler(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterAssembler(lua_tointeger(L, 1));
end;


function lua_registerAutoAssemblerPrologue(L: PLua_State): integer; cdecl;
var
  f: integer;
  routine: string;
  lc: tluacaller;
begin
  result:=0;

  if lua_gettop(L)=1 then
  begin
    if lua_isfunction(L, 1) then
    begin
      lua_pushvalue(L, 1);
      f:=luaL_ref(L,LUA_REGISTRYINDEX);

      lc:=TLuaCaller.create;
      lc.luaroutineIndex:=f;
    end
    else
    if lua_isstring(L,1) then
    begin
      routine:=lua_tostring(L,-1);
      lc:=TLuaCaller.create;
      lc.luaroutine:=routine;
    end
    else exit;

    lua_pushinteger(L, registerAutoAssemblerPrologue(lc.AutoAssemblerPrologueEvent));
    result:=1;
  end;
end;

function lua_unregisterAutoAssemblerPrologue(L: PLua_State): integer; cdecl;
begin
  result:=0;
  if lua_gettop(L)>0 then
    unregisterAutoAssemblerPrologue(lua_tointeger(L, 1));
end;

function lua_shortCutToText(L: PLua_State): integer; cdecl;
begin
  if lua_gettop(L)>0 then
  begin
    lua_pushstring(L, ShortCutToText(TShortCut(lua_tointeger(L, 1))));
    result:=1;
  end
  else
    result:=0;
end;

function lua_textToShortCut(L: PLua_State): integer; cdecl;
begin
  if lua_gettop(L)>0 then
  begin
    lua_pushinteger(L, TextToShortCut(Lua_ToString(L, 1)));
    result:=1;
  end
  else
    result:=0;
end;

function lua_outputDebugString(L: PLua_State): integer; cdecl;
begin
  if lua_gettop(L)>0 then
    OutputDebugString(pchar(Lua_ToString(L, 1)));

  result:=0;
end;

function getUserRegistryEnvironmentVariable(L: PLua_State): integer; cdecl;
var
  name: string;
  r: Tregistry;
begin
  result:=0;
  if lua_gettop(L)>0 then
  begin
    name:=Lua_ToString(L, 1);

    r:=tregistry.Create;
    try
      r.RootKey:=HKEY_CURRENT_USER;
      if r.OpenKey('\Environment',false) then
      begin
        if r.ValueExists(name) then
        begin
          lua_pushstring(L, r.ReadString(name));
          result:=1;
        end;
      end;
    finally
      r.free;
    end;

  end;
end;

function setUserRegistryEnvironmentVariable(L: PLua_State): integer; cdecl;
var
  name, value: string;
  r: tregistry;
begin
  result:=0;
  if lua_gettop(L)>1 then
  begin
    name:=Lua_ToString(L, 1);
    value:=Lua_ToString(L, 2);

    r:=tregistry.Create;
    try
      r.RootKey:=HKEY_CURRENT_USER;
      if r.OpenKey('\Environment',false) then
        r.WriteString(name, value);
    finally
      r.free;
    end;
  end;
end;

function broadcastEnvironmentUpdate(L: PLua_State): integer; cdecl;
var rv: dword;
begin
  result:=0;

  SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0, LPARAM(pchar('Environment')), SMTO_ABORTIFHUNG, 5000, rv);
end;

var winmm: THandle=0;
var PlaySoundA: function (pszSound: LPCSTR; hmod: HModule; fdwSound: DWORD): BOOL; stdcall;

function lua_playSound(L: PLua_State): integer; cdecl;
const
    SND_NODEFAULT = 2;
    SND_MEMORY = 4;
    SND_LOOP = 8;
    SND_NOSTOP = 16;
    SND_SYNC = 0;
    SND_ASYNC = 1;
    SND_PURGE = 64;
    SND_APPLICATION = 128;
var
  o: tobject;
  ms: TMemorystream;
  playparam: dword;
begin
  if lua_gettop(L)>=1 then
  begin
    if winmm=0 then
      winmm:=LoadLibrary('winmm.dll');

    if (winmm<>0) then
    begin
      if not assigned(PlaySoundA) then
        PlaySoundA:=GetProcAddress(winmm,'PlaySoundA');

      if assigned(PlaySoundA) then
      begin
        if lua_isuserdata(L,1) then
        begin
          o:=lua_ToCEUserData(L, 1);

          if o is TLuafile then
            ms:=TLuaFile(o).stream
          else
          if o is TMemoryStream then
            ms:=TMemoryStream(o)
          else
            raise exception.create('playSound: The parameter must be a table file or a memory stream. Nothing else');

          playparam:=SND_MEMORY;
          if (lua_gettop(L)>=2) and lua_toboolean(L,2) then
            playparam:=playparam or SND_SYNC
          else
            playparam:=playparam or SND_ASYNC;

          PlaySoundA(ms.Memory, NULL, playparam);
        end;


      end;
    end;
  end;

end;

function createRef(L: PLua_State): integer; cdecl;
begin
  lua_pushinteger(L, luaL_ref(L, LUA_REGISTRYINDEX));
  result:=1;
end;

function getRef(L: PLua_State): integer; cdecl;
begin
  lua_rawgeti(Luavm, LUA_REGISTRYINDEX, lua_tointeger(L,1));
  result:=1;
end;

function destroyRef(L: PLua_State): integer; cdecl;
begin
  luaL_unref(L, LUA_REGISTRYINDEX, lua_tointeger(L,1));
  result:=0;
end;

function activateProtection(L: PLua_State): integer; cdecl;
begin
  if lua_gettop(L)=0 then
    protectme
  else
    protectme(lua_tointeger(L,1));
end;

function getLuaEngine(L:PLua_State): integer; cdecl;
begin
  if frmLuaEngine=nil then
    frmLuaEngine:=TfrmLuaEngine.Create(application);

  luaclass_newClass(L, frmLuaEngine);
  result:=1;
end;

function getApplication(L:PLua_State): integer; cdecl;
begin
  luaclass_newClass(L, application);
  result:=1;
end;

function lua_stringToMD5String(L:PLua_State): integer; cdecl;
var s: string;
begin
  if lua_gettop(L)=1 then
  begin
    s:=Lua_ToString(L,1);
    lua_pushstring(L, MD5Print(MD5String(s)));
    result:=1;
  end
  else
    result:=0;
end;

function lua_ConvertKeyComboToString(L:PLua_State): integer; cdecl;
var
  keycombo: TKeyCombo;
  keycount: integer;
  i: integer;
begin
  zeromemory(@keycombo, sizeof(keycombo));
  keycount:=min(lua_gettop(L), 5);

  if (keycount=1) and lua_istable(L,1) then
  begin
    for i:=0 to 4 do
    begin
      lua_pushinteger(L, i+1);
      lua_gettable(L, 1);
      if lua_isnil(L, -1) then  //end of the list
      begin
        lua_pop(L,1);
        break;
      end
      else
      begin
        keycombo[i]:=lua_tointeger(L,-1);
        lua_pop(L,1);
      end;
    end;

  end
  else
  begin
    for i:=0 to keycount-1 do
      keycombo[i]:=lua_tointeger(L, i+1);
  end;

  lua_pushstring(L, ConvertKeyComboToString(keycombo));
  result:=1;
end;

function restoreSeDebugPrivilege(L:PLua_State): integer; cdecl;
var
  tp: TTokenPrivileges;
  prev: TTokenPrivileges;
  returnlength: dword;
  tokenhandle: thandle;
begin
  result:=0;
  if ownprocesshandle <> 0 then
  begin
    if OpenProcessToken(ownprocesshandle, TOKEN_QUERY or TOKEN_ADJUST_PRIVILEGES, tokenhandle) then
    begin
      ZeroMemory(@tp, sizeof(tp));

      if lookupPrivilegeValue(nil, 'SeDebugPrivilege', tp.Privileges[0].Luid) then
      begin
        tp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
        tp.PrivilegeCount := 1; // One privilege to set
        if AdjustTokenPrivileges(tokenhandle, False, tp, sizeof(tp),  prev, returnlength) then
        begin
          lua_pushboolean(L, true);
          result:=1;
        end


      end;

      closehandle(tokenhandle);
    end;

  end;
end;


procedure InitializeLua;
var s: tstringlist;
  k32: THandle;
begin

  LuaVM:=lua_open();

  if LuaVM<>nil then
  begin
    luaL_openlibs(LuaVM);

    lua_atpanic(LuaVM, LuaPanic);
    lua_register(LuaVM, 'print', print);
    lua_register(LuaVM, 'sleep', sleep);
    lua_register(LuaVM, 'pause', pause);
    lua_register(LuaVM, 'unpause', unpause);
    lua_register(LuaVM, 'readBytes', readbytes);
    lua_register(LuaVM, 'writeBytes', writebytes);
    lua_register(LuaVM, 'readInteger', readInteger);
    lua_register(LuaVM, 'readQword', readQword);
    lua_register(LuaVM, 'readPointer', readPointer);
    lua_register(LuaVM, 'readFloat', readFloat);
    lua_register(LuaVM, 'readDouble', readDouble);
    lua_register(LuaVM, 'readString', readString);
    lua_register(LuaVM, 'readIntegerLocal', readIntegerLocal);
    lua_register(LuaVM, 'readQwordLocal', readQwordLocal);
    lua_register(LuaVM, 'readPointerLocal', readPointerLocal);
    lua_register(LuaVM, 'readFloatLocal', readFloatLocal);
    lua_register(LuaVM, 'readDoubleLocal', readDoubleLocal);
    lua_register(LuaVM, 'readStringLocal', readStringLocal);

    lua_register(LuaVM, 'writeInteger', writeInteger);
    lua_register(LuaVM, 'writeQword', writeQword);
    lua_register(LuaVM, 'writePointer', writePointer);
    lua_register(LuaVM, 'writeFloat', writeFloat);
    lua_register(LuaVM, 'writeDouble', writeDouble);
    lua_register(LuaVM, 'writeString', writeString);
    lua_register(LuaVM, 'writeIntegerLocal', writeIntegerLocal);
    lua_register(LuaVM, 'writeQwordLocal', writeQwordLocal);
    lua_register(LuaVM, 'writePointerLocal', writePointerLocal);
    lua_register(LuaVM, 'writeFloatLocal', writeFloatLocal);
    lua_register(LuaVM, 'writeDoubleLocal', writeDoubleLocal);
    lua_register(LuaVM, 'writeStringLocal', writeStringLocal);


    lua_register(LuaVM, 'readBytesLocal', readbyteslocal);
    lua_register(LuaVM, 'writeBytesLocal', writebyteslocal);
    lua_register(LuaVM, 'autoAssemble', autoAssemble_lua);
    lua_register(LuaVM, 'showMessage', showMessage_lua);
    lua_register(LuaVM, 'inputQuery', inputQuery_lua);
    lua_register(LuaVM, 'getPixel', getPixel);
    lua_register(LuaVM, 'getMousePos', getMousePos);
    lua_register(LuaVM, 'setMousePos', setMousePos);
    lua_register(LuaVM, 'createTableEntry', createTableEntry);
    lua_register(LuaVM, 'getTableEntry', getTableEntry);

    initializeLuaMemoryRecord;




    lua_register(LuaVM, 'isKeyPressed', isKeyPressed);
    lua_register(LuaVM, 'keyDown', keyDown);
    lua_register(LuaVM, 'keyUp', keyUp);
    lua_register(LuaVM, 'doKeyPress', doKeyPress);
    lua_register(LuaVM, 'getProcessIDFromProcessName', getProcessIDFromProcessName);
    lua_register(LuaVM, 'openProcess', openProcess);
    lua_register(LuaVM, 'debugProcess', debugProcess);
    lua_register(LuaVM, 'debug_getBreakpointList', debug_getBreakpointList);
    lua_register(LuaVM, 'debug_isDebugging', debug_isDebugging);
    lua_register(LuaVM, 'debug_canBreak', debug_canBreak);
    lua_register(LuaVM, 'debug_setBreakpoint', debug_setBreakpoint);
    lua_register(LuaVM, 'debug_removeBreakpoint', debug_removeBreakpoint);
    lua_register(LuaVM, 'debug_continueFromBreakpoint', debug_continueFromBreakpoint);
    lua_register(LuaVM, 'closeCE', closeCE);
    lua_register(LuaVM, 'hideAllCEWindows', hideAllCEWindows);
    lua_register(LuaVM, 'unhideMainCEwindow', unhideMainCEwindow);


    initializeLuaGroupbox;


    lua_register(LuaVM, 'createLabel', createLabel);
    lua_register(LuaVM, 'createSplitter', createSplitter);
    lua_register(LuaVM, 'createPaintBox', createPaintBox);

    lua_register(LuaVM, 'messageDialog', messageDialog);
    lua_register(LuaVM, 'speedhack_setSpeed', speedhack_setSpeed);
    lua_register(LuaVM, 'injectDLL', injectDLL);
    lua_register(LuaVM, 'getAutoAttachList', getAutoAttachList);


    lua_register(LuaVM, 'generateAPIHookScript', generateAPIHookScript_lua);
    lua_register(LuaVM, 'createProcess', createProcess);
    lua_register(LuaVM, 'AOBScan', AOBScan);
    lua_register(LuaVM, 'getOpenedProcessID', getOpenedProcessID);
    lua_register(LuaVM, 'getAddress', getAddress);
    lua_register(LuaVM, 'getModuleSize', getModuleSize);

    lua_register(LuaVM, 'reinitializeSymbolhandler', reinitializeSymbolhandler);
    lua_register(LuaVM, 'reinitializeDotNetSymbolhandler', reinitializeDotNetSymbolhandler);
    lua_register(LuaVM, 'enumModules', enumModules);




    //ce6.1
    lua_register(LuaVM, 'getNameFromAddress', getNameFromAddress);
    lua_register(LuaVM, 'inModule', inModule);
    lua_register(LuaVM, 'inSystemModule', inSystemModule);
    lua_register(LuaVM, 'getCommonModuleList', getCommonModuleList);

    initializeLuaImage;

    initializeLuaRasterImage;

    initializeLuaGenericHotkey;



    initializeLuaObject;
    InitializeLuaComponent;


    InitializeLuaControl;

    initializeLuaWinControl;

    initializeLuaStrings;
    initializeLuaStringlist;

    initializeLuaForm;
    initializeLuaPanel;
    initializeLuaImage;

    initializeLuaEdit;





    initializeLuaMemo;


    InitializeLuaButton;

    lua_register(LuaVM, 'createToggleBox', createToggleBox);

    initializeLuaCheckbox;
    initializeLuaRadioGroup;
    initializeLuaListbox;
    initializeLuaCombobox;
    initializeLuaProgressbar;
    initializeLuaTrackbar;


    initializeLuaListColumn;
    initializeLuaCollection;

    initializeLuaListColumns;


    initializeLuaListItem;


    initializeLuaListItems;


    initializeLuaListview;
    initializeLuaTreeview;
    initializeLuaTimer;





    lua_register(LuaVM, 'openDialog_execute', openDialog_execute);
    lua_register(LuaVM, 'createOpenDialog', createOpenDialog);
    lua_register(LuaVM, 'createSaveDialog', createSaveDialog);
    lua_register(LuaVM, 'createSelectDirectoryDialog', createSelectDirectoryDialog);


    lua_register(LuaVM, 'createMemoryStream', createMemoryStream);
    lua_register(LuaVM, 'createFileStream', createFileStream);


    Lua_register(LuaVM, 'getSettingsForm', getSettingsForm);
    Lua_register(LuaVM, 'getMemoryViewForm', getMemoryViewForm);
    Lua_register(LuaVM, 'getMainForm', getMainForm);
    Lua_register(LuaVM, 'getAddressList', getAddressList);
    Lua_register(LuaVM, 'getFreezeTimer', getFreezeTimer);
    Lua_register(LuaVM, 'getUpdateTimer', getUpdateTimer);

    lua_register(luavm, 'setGlobalKeyPollInterval', setGlobalKeyPollInterval);
    lua_register(luavm, 'setGlobalDelayBetweenHotkeyActivation', setGlobalDelayBetweenHotkeyActivation);

    initializeLuaMemoryview;
    initializeLuaTableFile;

    InitializeLuaXMPlayer;


    Lua_register(LuaVM, 'writeRegionToFile', writeRegionToFile);
    Lua_register(LuaVM, 'readRegionFromFile', readRegionFromFile);

    Lua_register(LuaVM, 'registerSymbol', registersymbol);
    Lua_register(LuaVM, 'unregisterSymbol', unregistersymbol);
    Lua_register(LuaVM, 'getSymbolInfo', getSymbolInfo);

    Lua_register(LuaVM, 'resetLuaState', resetLuaState);
    Lua_register(LuaVM, 'reloadSettingsFromRegistry', reloadSettingsFromRegistry);


    InitializeLuaCheatComponent;


    initializeMemoryRecordHotkey;

    InitializeLuaAddresslist;



    Lua_register(LuaVM, 'createMemScan', createMemScan);
    Lua_register(LuaVM, 'getCurrentMemscan', getCurrentMemscan);

    InitializeMemscan;
    InitializeFoundlist;


    Lua_register(LuaVM, 'supportCheatEngine', supportCheatEngine);
    Lua_register(LuaVM, 'fuckCheatEngine', fuckCheatEngine);



    lua_register(LuaVM, 'inheritsFromObject', inheritsFromObject);
    lua_register(LuaVM, 'inheritsFromComponent', inheritsFromComponent);
    lua_register(LuaVM, 'inheritsFromControl', inheritsFromControl);
    lua_register(LuaVM, 'inheritsFromWinControl', inheritsFromWinControl);

    Lua_register(LuaVM, 'beep', beep);

    lua_register(LuaVM, 'dbk_initialize', dbk_initialize);
    lua_register(LuaVM, 'dbk_useKernelmodeOpenProcess', dbk_useKernelmodeOpenProcess);
    lua_register(LuaVM, 'dbk_useKernelmodeProcessMemoryAccess', dbk_useKernelmodeProcessMemoryAccess);
    lua_register(LuaVM, 'dbk_useKernelmodeQueryMemoryRegions', dbk_useKernelmodeQueryMemoryRegions);
    lua_register(LuaVM, 'dbk_getPEProcess', dbk_getPEProcess);
    lua_register(LuaVM, 'dbk_getPEThread', dbk_getPEThread);
    lua_register(LuaVM, 'dbk_executeKernelMemory', dbk_executeKernelMemory);
    lua_register(LuaVM, 'dbk_readMSR', dbk_readMSR);
    lua_register(LuaVM, 'dbk_writeMSR', dbk_writeMSR);

    lua_register(LuaVM, 'allocateSharedMemory', allocateSharedMemory);
    lua_register(LuaVM, 'deallocateSharedMemory', deallocateSharedMemory);
    lua_register(LuaVM, 'getCheatEngineDir', getCheatEngineDir);

    lua_register(LuaVM, 'disassemble', disassemble_lua);
    lua_register(LuaVM, 'splitDisassembledString', splitDisassembledString);
    lua_register(LuaVM, 'getInstructionSize', getInstructionSize);
    lua_Register(LuaVM, 'getPreviousOpcode', getPreviousOpcode);

    initializegraphiccontrol;

    lua_register(LuaVM, 'disassemblerview_getSelectedAddress', disassemblerview_getSelectedAddress);
    lua_register(LuaVM, 'disassemblerview_setSelectedAddress', disassemblerview_setSelectedAddress);
    lua_register(LuaVM, 'disassemblerview_onSelectionChange', disassemblerview_onSelectionChange);

    lua_register(LuaVM, 'hexadecimalview_getTopAddress', hexadecimalview_getTopAddress);
    lua_register(LuaVM, 'hexadecimalview_setTopAddress', hexadecimalview_setTopAddress);
    lua_register(LuaVM, 'hexadecimalview_onAddressChange', hexadecimalview_onAddressChange);
    lua_register(LuaVM, 'hexadecimalview_onByteSelect', hexadecimalview_onByteSelect);

    lua_register(LuaVM, 'registerCustomTypeLua', registerCustomTypeLua);
    lua_register(LuaVM, 'registerCustomTypeAutoAssembler', registerCustomTypeAutoAssembler);

    lua_register(LuaVM, 'getForegroundProcess', getForegroundProcess);

    lua_register(LuaVM, 'cheatEngineIs64Bit', cheatEngineIs64Bit);
    lua_register(LuaVM, 'targetIs64Bit', targetIs64Bit);

    lua_register(LuaVM, 'getFormCount', getFormCount);
    lua_register(LuaVM, 'getForm', getForm);
    lua_register(LuaVM, 'registerFormAddNotification', registerFormAddNotification);
    Lua_Register(LuaVM, 'unregisterFormAddNotification', unregisterFormAddNotification);


    lua_register(LuaVM, 'onAutoGuess', onAutoGuess);
    lua_register(LuaVM, 'onAPIPointerChange', onAPIPointerChange);

    lua_register(LuaVM, 'setAPIPointer', setAPIPointer);

    lua_register(LuaVM, 'dbvm_initialize', dbvm_initialize);

    lua_register(LuaVM, 'shellExecute', shellExecute);
    lua_register(LuaVM, 'getTickCount', getTickCount_lua);
    lua_register(LuaVM, 'processMessages', processMessages);

    lua_register(LuaVM, 'integerToUserData', integerToUserData);
    lua_register(LuaVM, 'userDataToInteger', userDataToInteger);



    lua_register(LuaVM, 'writeToClipboard', writeToClipboard);
    lua_register(LuaVM, 'readFromClipboard', readFromClipboard);

    lua_register(LuaVM, 'createBitmap', createBitmap);
    lua_register(LuaVM, 'createPNG', createPNG);
    lua_register(LuaVM, 'createJpeg', createJpeg);
    lua_register(LuaVM, 'errorOnLookupFailure', errorOnLookupFailure);

    lua_register(LuaVM, 'loadPlugin', loadPlugin);

    lua_register(LuaVM, 'getCEVersion', getCEVersion);

    lua_register(LuaVM, 'utf8ToAnsi', lua_Utf8ToAnsi);
    lua_register(LuaVM, 'ansiToUtf8', lua_AnsiToUtf8);

    lua_register(LuaVM, 'fullAccess', fullAccess);
    lua_register(LuaVM, 'getProcesslist', getProcessList_lua);
    lua_register(LuaVM, 'getProcessList', getProcessList_lua);
    lua_register(LuaVM, 'getThreadlist', getThreadlist_lua);
    lua_register(LuaVM, 'getThreadList', getThreadlist_lua);

    Lua_register(LuaVM, 'createTreeView', createTreeView);
    Lua_register(LuaVM, 'loadTable', lua_loadTable);
    Lua_register(LuaVM, 'saveTable', lua_saveTable);
    Lua_register(LuaVM, 'detachIfPossible', lua_DetachIfPossible);
    Lua_register(LuaVM, 'getComment', getComment);
    Lua_register(LuaVM, 'setComment', setComment);
    Lua_register(LuaVM, 'getHeader', getHeader);
    Lua_register(LuaVM, 'setHeader', setHeader);

    lua_register(LuaVM, 'createClass', lua_createClass);
    lua_register(LuaVM, 'openLuaServer', openLuaServer);

    lua_register(LuaVM, 'registerAutoAssemblerCommand', lua_registerAutoAssemblerCommand);
    lua_register(LuaVM, 'unregisterAutoAssemblerCommand', lua_unregisterAutoAssemblerCommand);

    lua_register(LuaVM, 'registerSymbolLookupCallback', lua_registerSymbolLookupCallback);
    lua_register(LuaVM, 'unregisterSymbolLookupCallback', lua_unregisterSymbolLookupCallback);
    lua_register(LuaVM, 'registerAddressLookupCallback', lua_registerAddressLookupCallback);
    lua_register(LuaVM, 'unregisterAddressLookupCallback', lua_unregisterAddressLookupCallback);

    lua_register(LuaVM, 'registerGlobalDisassembleOverride', lua_registerGlobalDisassembleOverride);
    lua_register(LuaVM, 'unregisterGlobalDisassembleOverride', lua_unregisterGlobalDisassembleOverride);

    lua_register(LuaVM, 'registerStructureDissectOverride', lua_registerStructureDissectOverride);
    lua_register(LuaVM, 'unregisterStructureDissectOverride', lua_unregisterStructureDissectOverride);

    lua_register(LuaVM, 'registerStructureNameLookup', lua_registerStructureNameLookup);
    lua_register(LuaVM, 'unregisterStructureNameLookup', lua_unregisterStructureNameLookup);

    lua_register(LuaVM, 'registerAssembler', lua_registerAssembler);
    lua_register(LuaVM, 'unregisterAssembler', lua_unregisterAssembler);

    lua_register(LuaVM, 'registerAutoAssemblerPrologue', lua_registerAutoAssemblerPrologue);
    lua_register(LuaVM, 'unregisterAutoAssemblerPrologue', lua_unregisterAutoAssemblerPrologue);


    lua_register(LuaVM, 'shortCutToText', lua_shortCutToText);
    lua_register(LuaVM, 'textToShortCut', lua_textToShortCut);

    lua_register(LuaVM, 'inMainThread', inMainThread);
    lua_register(LuaVM, 'synchronize', lua_synchronize);
    lua_register(LuaVM, 'checkSynchronize', lua_checkSynchronize);

    lua_register(LuaVM, 'playSound', lua_playSound);

    lua_register(LuaVM, 'outputDebugString', lua_outputDebugString);
    lua_register(LuaVM, 'broadcastEnvironmentUpdate', broadcastEnvironmentUpdate);
    lua_register(LuaVM, 'getUserRegistryEnvironmentVariable', getUserRegistryEnvironmentVariable);
    lua_register(LuaVM, 'setUserRegistryEnvironmentVariable', setUserRegistryEnvironmentVariable);

    lua_register(LuaVM, 'createRef', createRef);
    lua_register(LuaVM, 'getRef', getRef);
    lua_register(LuaVM, 'destroyRef', destroyRef);

    lua_register(LuaVM, 'activateProtection', activateProtection);
    lua_register(LuaVM, 'getLuaEngine', getLuaEngine);
    lua_register(LuaVM, 'getApplication', getApplication);

    lua_Register(LuaVM, 'stringToMD5String', lua_stringToMD5String);
    lua_register(LuaVM, 'convertKeyComboToString', lua_ConvertKeyComboToString);
    lua_register(LuaVM, 'restoreSeDebugPrivilege', restoreSeDebugPrivilege);

    initializeLuaCustomControl;




    initializeLuaPicture;
    initializeLuaPen;
    initializeLuaBrush;
    initializeLuaFont;
    initializeLuaCanvas;
    initializeLuaMenu;

    initializeLuaDebug; //eventually I should add a LuaLuaDebug...
    initializeLuaThread;
    initializeLuaGraphic;
    initializeLuaOldD3DHook;
    initializeLuaD3DHook;
    initializeLuaStructure;
    initializeLuaRegion;
    initializeLuaDisassembler;
    initializeLuaDissectCode;
    initializeLuaByteTable;
    initializeLuaBinary;
    initializeLuaPipeClient;
    initializeLuaPipeServer;
    initializeLuaSymbolListHandler;
    initializeLuaFindDialog;
    initializeLuaSettings;
    initializeLuaPageControl;

    initializeLuaCalendar;
    initializeLuaRipRelativeScanner;



    s:=tstringlist.create;
    try
      //ce 6.0 compatibility. 6.0 has these methods in the stringlist instead of the strings class
      s.add('package.path = package.path .. ";?.lua";');

{$ifdef cpu64}
      s.add('package.cpath = package.cpath .. [[;'+getcedir+'\clibs64\?.dll]]');
      s.add('package.cpath = package.cpath .. [[;.\clibs64\?.dll]]');
{$else}
      s.add('package.cpath = package.cpath .. [[;'+getcedir+'\clibs32\?.dll]]');
      s.add('package.cpath = package.cpath .. [[;.\clibs32\?.dll]]');
{$endif}
      s.add('stringlist_getCount=strings_getCount');
      s.add('stringlist_getString=strings_getString');
      s.add('stringlist_add=strings_add');
      s.add('stringlist_remove=strings_remove');

      //same for the rename of memrec to memoryrecord
      s.add('memrec_setDescription = memoryrecord_setDescription');
      s.add('memrec_getDescription = memoryrecord_getDescription');
      s.add('memrec_getAddress = memoryrecord_getAddress');
      s.add('memrec_setAddress = memoryrecord_setAddress');
      s.add('memrec_getType = memoryrecord_getType');
      s.add('memrec_setType = memoryrecord_setType');
      s.add('memrec_getValue = memoryrecord_getValue');
      s.add('memrec_setValue = memoryrecord_setValue');
      s.add('memrec_getScript = memoryrecord_getScript');
      s.add('memrec_isActive = memoryrecord_isActive');
      s.add('memrec_freeze = memoryrecord_freeze');
      s.add('memrec_unfreeze = memoryrecord_unfreeze');
      s.add('memrec_setColor = memoryrecord_setColor');
      s.add('memrec_appendToEntry = memoryrecord_appendToEntry');
      s.add('memrec_delete = memoryrecord_delete');
      s.add('getAddressFromName = getAddress');

      //timer onInterval has been renamed to timer onTimer
      s.add('timer_onInterval = timer_onTimer');

      //dbvm, most dbvm functions are just dbk functions that fallback to dbvm on failure
      s.add('dbvm_readMSR = dbk_readMSR');
      s.add('dbvm_writeMSR = dbk_writeMSR');

      k32:=loadlibrary('kernel32.dll');
      s.add('windows_OpenProcess=0x'+inttohex(ptruint(getProcAddress(k32, 'OpenProcess')),8));
      s.add('windows_ReadProcessMemory=0x'+inttohex(ptruint(getProcAddress(k32, 'ReadProcessMemory')),8));
      s.add('windows_WriteProcessMemory=0x'+inttohex(ptruint(getProcAddress(k32, 'WriteProcessMemory')),8));
      s.add('windows_VirtualQueryEx=0x'+inttohex(ptruint(getProcAddress(k32, 'VirtualQueryEx')),8));

      s.add('dbk_OpenProcess=0x'+inttohex(ptruint(@DBK32functions.OP),8));
      s.add('dbk_NtOpenProcess=0x'+inttohex(ptruint(@DBK32functions.NOP),8));
      s.add('dbk_ReadProcessMemory=0x'+inttohex(ptruint(@DBK32functions.RPM),8));
      s.add('dbk_WriteProcessMemory=0x'+inttohex(ptruint(@DBK32functions.WPM),8));
      s.add('dbk_VirtualQueryEx=0x'+inttohex(ptruint(@DBK32functions.VQE),8));
      s.add('dbk_ReadPhysicalMemory=0x'+inttohex(ptruint(@DBK32functions.ReadPhysicalMemory),8));
      s.add('dbk_WritePhysicalMemory=0x'+inttohex(ptruint(@DBK32functions.WritePhysicalMemory),8));
      s.add('VirtualQueryExPhysical=0x'+inttohex(ptruint(@VirtualQueryExPhysical),8));

      s.add('dbvm_ReadPhysicalMemory=0x'+inttohex(ptruint(@vmxfunctions.dbvm_read_physical_memory),8));
      s.add('dbvm_WritePhysicalMemory=0x'+inttohex(ptruint(@vmxfunctions.dbvm_write_physical_memory),8));


      s.add('dbvm_block_interrupts=0x'+inttohex(ptruint(@vmxfunctions.dbvm_block_interrupts),8));
      s.add('dbvm_raise_privilege=0x'+inttohex(ptruint(@vmxfunctions.dbvm_raise_privilege),8));
      s.add('dbvm_restore_interrupts=0x'+inttohex(ptruint(@vmxfunctions.dbvm_restore_interrupts),8));
      s.add('dbvm_changeselectors=0x'+inttohex(ptruint(@vmxfunctions.dbvm_changeselectors),8));



      lua_doscript(s.text);

    finally
      s.free;
    end;
  end;

end;

initialization
  LuaCS:=TCriticalSection.create;
  luarefcs:=TCriticalSection.create;

  InitializeLua;



finalization
  if LuaCS<>nil then
    LuaCS.free;

  if LuaVM<>nil then
    lua_close(LuaVM);

end.

