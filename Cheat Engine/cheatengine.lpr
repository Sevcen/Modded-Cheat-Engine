program cheatengine;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  controls, sysutils, Forms, dialogs, bogus, MainUnit, CEDebugger,
  NewKernelHandler, CEFuncProc, ProcessHandlerUnit, symbolhandler,
  Assemblerunit, hypermode, byteinterpreter, addressparser, autoassembler,
  ProcessWindowUnit, MainUnit2, Filehandler, dbvmPhysicalMemoryHandler,
  frameHotkeyConfigUnit, formsettingsunit, HotkeyHandler, formhotkeyunit,
  AdvancedOptionsUnit, inputboxtopunit, plugin, pluginexports, tlgUnit,
  aboutunit, frmProcesswatcherExtraUnit, frmProcessWatcherUnit,
  ModuleSafetyUnit, frmExcludeHideUnit, ConfigUnrandomizerFrm, HotKeys,
  TypePopup, CommentsUnit, FoundCodeUnit, foundlisthelper, unrandomizer,
  SaveFirstScan, savedscanhandler, memscan, formScanningUnit, KernelDebugger,
  formDifferentBitSizeUnit, formAddressChangeUnit, Changeoffsetunit, speedhack2,
  formPointerOrPointeeUnit, AccessCheck, formmemoryregionsunit, OpenSave,
  formProcessInfo, frmautoinjectunit, MenuItemExtra, MemoryBrowserFormUnit,
  disassemblerviewlinesunit, disassemblerviewunit, PasteTableentryFRM,
  frmBreakpointlistunit, DissectCodeThread, DissectCodeunit, Valuechange,
  FindWindowUnit, stacktrace2, frmstacktraceunit, frmBreakThreadUnit,
  FormDebugStringsUnit, frmDissectwindowUnit, frmCapturedTimersUnit,
  frmEnumerateDLLsUnit, frmThreadlistunit, frmMemoryAllocHandlerUnit,
  circularBuffer, PEInfoFunctions, PEInfounit, FileMapping, frmFindstaticsUnit,
  frmModifyRegistersUnit, frmHeapsUnit, savedisassemblyfrm,
  frmSaveMemoryRegionUnit, frmLoadMemoryunit, formAddToCodeList,
  frmFillMemoryUnit, frmCodecaveScannerUnit, frmSelectionlistunit,
  symbolconfigunit, frmFloatingPointPanelUnit, frmTracerUnit, DriverList,
  frmRegistersunit, formChangedAddresses, frmGDTunit, frmIDTunit,
  frmDisassemblyscanunit, frmReferencedStringsUnit, StructuresAddElementfrm,
  Structuresfrm, PointerscannerSettingsFrm, simpleaobscanner,
  PointerscanresultReader, pointervaluelist, rescanhelper, pointerscannerfrm,
  VirtualMemory, ValueFinder, frmRescanPointerUnit, SyncObjs2,
  ManualModuleLoader, SynHighlighterAA, APIhooktemplatesettingsfrm,
  frmAAEditPrefsUnit, disassembler, hexviewunit, guisafecriticalsection,
  debugeventhandler, formFoundcodeListExtraUnit, debuggertypedefinitions,
  addresslist, MemoryRecordUnit, ThreadlistExFRM, windows7taskbar, tablist,
  frmStructuresConfigUnit, VEHDebugger, VEHDebugSharedMem, DebuggerInterface,
  WindowsDebugger, DebuggerInterfaceAPIWrapper, frmDebugEventsUnit, changelist,
  tableconverter, DBK32functions, debug, multicpuexecution, vmxfunctions,
  frmPagingUnit, bigmemallochandler, KernelDebuggerInterface, CustomTypeHandler,
  LuaHandler, frmLuaEngineUnit, frmMemviewPreferencesUnit,
  frmBreakpointConditionUnit, frmTracerConfigUnit, frmStackViewUnit, luaJit,
  ScrollBoxEx, fileaccess, ceguicomponents, formdesignerunit, LuaCaller,
  LuaSyntax, cesupport, trainergenerator, genericHotkey,
  frmExeTrainerGeneratorUnit, luafile, xmplayer_server, xmplayer_defines,
  ExtraTrainerComponents, frmAdConfigUnit, IconStuff, cetranslator,
  frmStringMapUnit, MemFuncs, frmStringPointerScanUnit,
  frmStructPointerRescanUnit, sharedMemory, disassemblerComments,
  frmFilePatcherUnit, LuaCanvas, LuaPen, LuaFont, LuaBrush, LuaPicture, LuaMenu,
  LuaDebug, frmUltimapUnit, DBK64SecondaryLoader, frmHotkeyExUnit,
  SymbolListHandler, networkInterface, networkInterfaceApi, networkConfig,
  LuaThread, LuaGraphic, LuaProgressBar, d3dhookUnit, LuaOldD3DHook,
  LuaWinControl, frmSetCrosshairUnit, StructuresFrm2, scrollTreeView,
  frmStructures2ElementInfoUnit, frmStructureLinkerUnit, LuaMemoryRecord,
  LuaStructure, LuaForm, regionex, LuaRegion, frmgroupscanalgoritmgeneratorunit,
  vartypestrings, LuaXMPlayer, groupscancommandparser, LuaMemscan, LuaFoundlist,
  LuaRadioGroup, RemoteMemoryManager, LuaRasterImage, multilineinputqueryunit,
  LuaCheatComponent, LuaAddresslist, frmDriverLoadedUnit, memdisplay,
  frmSortPointerlistUnit, LuaClassArray, LuaObject, LuaComponent, LuaControl,
  LuaStrings, LuaStringlist, LuaCustomControl, LuaGraphicControl, LuaPanel,
  LuaImage, LuaButton, LuaCheckbox, LuaClass, LuaGroupbox, LuaListbox,
  LuaCombobox, LuaTrackbar, LuaCollectionItem, LuaListcolumn, LuaEdit, LuaMemo,
  LuaCollection, LuaListColumns, LuaListItem, LuaListItems, LuaListview,
  LuaTimer, LuaGenericHotkey, LuaFileDialog, LuaStream, LuaTableFile,
  LuaMemoryRecordHotkey, LuaMemoryView, LuaD3DHook, CustomBase85,
  frmMemoryViewExUnit, LuaDisassembler, LuaDissectCode, LuaByteTable, LuaBinary,
  frmD3DHookSnapshotConfigUnit, frmsnapshothandlerUnit, frmSaveSnapshotsUnit,
  frmD3DTrainerGeneratorOptionsUnit, lua_server, frmAssemblyScanUnit,
  frmManualStacktraceConfigUnit, cvconst, NetworkDebuggerInterface,
  DisassemblerArm, LastDisassembleData, elfsymbols, assemblerArm,
  frmPointerscanConnectDialogUnit, PageMap, CELazySocket,
  PointerscanNetworkCommands, frmpointerrescanconnectdialogunit,
  frmMergePointerscanResultSettingsUnit, AddresslistEditor,
  FrmMemoryRecordDropdownSettingsUnit, frmMemrecComboboxUnit, tracerIgnore,
  DotNetPipe, DotNetTypes, LuaPipeServer, LuaPipe, LuaPipeClient,
  CEListviewItemEditor, LuaTreeview, LuaTreeNodes, LuaTreeNode, LuaCalendar,
  LuaSymbolListHandler, LuaFindDialog, LuaCommonDialog, LuaSettings,
  frmReferencedFunctionsUnit, LuaPageControl, DebugHelper,
  frmNetworkDataCompressionUnit, lazcontrols, LuaApplication, ProcessList,
  pointeraddresslist, frmResumePointerscanUnit, frmSetupPSNNodeUnit,
  PointerscanWorker, PointerscanStructures, PointerscanController, zstreamext,
  PointerscanConnector, PointerscanNetworkStructures, AsyncTimer, 
PointerscanSettingsIPConnectionList, MemoryStreamReader, commonTypeDefs, 
Parsers, Globals, NullStream, RipRelativeScanner, LuaRipRelativeScanner, 
VirtualQueryExCache;

{$R cheatengine.res}
//{$R manifest.res}  //lazarus now has this build in
//{$R Sounds.rc}
{$R Sounds.res}

{$ifdef cpu32}
{$SetPEFlags $20}
{$endif}

procedure HandleParameters;
{Keep in mind: Responsible for not making the mainform visible}
var i: integer;
  mainformvisible: boolean;
  p: string;
  tabletoload: string;
  origin: string;
begin
  tabletoload:='';
  origin:='';
  mainformvisible:=true;

  try

    for i:=1 to Paramcount do
    begin
      p:=paramstr(i);

      //ShowMessage('Param '+inttostr(i)+' = '+p);

      if p<>'' then
      begin
        if p[1]='-' then
        begin
          //could be -ORIGIN
          if uppercase(copy(p,1,8))='-ORIGIN:' then
            origin:=AnsiDequotedStr(copy(p,9, length(p)-8),'"');

        end
        else
        if (pos('.CETRAINER', uppercase(p))>0) or (pos('.CT', uppercase(p))>0) then
        begin
          //add the path of this CT to the lua lookup
          LUA_DoScript('package.path = package.path .. [[;'+ExtractFilePath(p)+'?.lua]];');

          mainformvisible:=uppercase(ExtractFileExt(p))<>'.CETRAINER';

          tabletoload:=p; //mark this trainer to be loaded
        end;
      end;

    end;

    if tabletoload<>'' then
    begin
      //it needs to load a table
      if fileexists(tabletoload)=false then //try to fix this
      begin
        if fileexists(ansitoutf8(tabletoload)) then
          tabletoload:=ansitoutf8(tabletoload)
        else
        if fileexists(utf8toansi(tabletoload)) then
          tabletoload:=utf8toansi(tabletoload);
      end;

      if origin='' then
        origin:=ExtractFilePath(tabletoload);

      if origin<>'' then
        LUA_DoScript('TrainerOrigin=[['+origin+']]');

      try
        try
          LoadTable(tabletoload,false);
        finally
          if ExtractFileName(tabletoload)='CET_TRAINER.CETRAINER' then //Let's just hope no-one names their trainer exactly this...
            DeleteFile(tabletoload);
        end;
      except
        on e: exception do
        begin
          MessageDlg('Failure loading the trainer. Reason :'+e.message, mterror, [mbok], 0);
          application.Terminate;
        end;
      end;
    end;
  except
  end;


  for i:=0 to mainform.LuaForms.count-1 do
    if tceform(mainform.luaforms[i]).visible then
    begin
      //first visible window in the formlist becomes the new taskbar window
      try
        tceform(mainform.luaforms[i]).ShowInTaskBar:=stAlways;
        tceform(mainform.luaforms[i]).formstyle:=fsStayOnTop;
        tceform(mainform.luaforms[i]).formstyle:=fsNormal;

        application.title:=tceform(mainform.luaforms[i]).Caption;
        application.icon:=tceform(mainform.luaforms[i]).Icon;
      except

      end;

      break;
    end;

  mainform.visible:=mainformvisible;
end;

begin
  Application.Title:='Cheat Engine 6.4';
  Application.Initialize;
  getcedir;

  doTranslation;

  symhandlerInitialize;

  Application.ShowMainForm:=false;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TMemoryBrowser, MemoryBrowser);
  Application.CreateForm(TformSettings, formSettings);
  Application.CreateForm(TAdvancedOptions, AdvancedOptions);
  Application.CreateForm(TComments, Comments);
  Application.CreateForm(TTypeForm, TypeForm);

  initcetitle;
  InitializeLuaScripts;

  handleparameters;
  Application.Run;
end.

