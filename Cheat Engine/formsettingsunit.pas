unit formsettingsunit;

{$MODE Delphi}

interface

uses
  windows, LCLProc, LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls,registry, Menus,ComCtrls,CEFuncProc,ExtCtrls,{tlhelp32,}CheckLst,
  Buttons, LResources, frameHotkeyConfigUnit, math,

  kerneldebugger,plugin,NewKernelHandler,CEDebugger,hotkeyhandler, debugHelper,
  formhotkeyunit, debuggertypedefinitions;


type Tpathspecifier=class(TObject)
  public
    path: string;
end;

type

  { TformSettings }

  TformSettings = class(TForm)
    cbDontusetempdir: TCheckBox;
    cbGlobalDebug: TCheckBox;
    cbKDebug: TRadioButton;
    cbShowallWindows: TCheckBox;
    cbAskIfTableHasLuascript: TCheckBox;
    cbAlwaysRunScript: TCheckBox;
    cbUseVEHDebugger: TRadioButton;
    cbUseWindowsDebugger: TRadioButton;
    CheckBox1: TCheckBox;
    cbCanStepKernelcode: TCheckBox;
    cbAllIncludesCustomType: TCheckBox;
    cbShowProcesslist: TCheckBox;
    cbOverrideExistingBPs: TCheckBox;
    cbVEHRealContextOnThreadCreation: TCheckBox;
    cbWaitAfterGuiUpdate: TCheckBox;
    defaultbuffer: TPopupMenu;
    Default1: TMenuItem;
    edtStacksize: TEdit;
    edtTempScanFolder: TEdit;
    GroupBox2: TGroupBox;
    GroupBox4: TGroupBox;
    Label2: TLabel;
    lblThreadFollowing: TLabel;
    Label4: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    LoadButton: TSpeedButton;
    Panel1: TPanel;
    pcDebugConfig: TPageControl;
    pnlConfig: TPanel;
    rbVEHHookThreadCreation: TRadioButton;
    rbVEHUseProcessWatcher: TRadioButton;
    rbVEHPollThread: TRadioButton;
    rbPageExceptions: TRadioButton;
    rbDebugAsBreakpoint: TRadioButton;
    rbgDebuggerInterface: TRadioGroup;
    rbInt3AsBreakpoint: TRadioButton;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    tsKernelDebugConfig: TTabSheet;
    tsVEHDebugConfig: TTabSheet;
    tsWindowsDebuggerConfig: TTabSheet;
    tvMenuSelection: TTreeView;
    pcSetting: TPageControl;
    GeneralSettings: TTabSheet;
    ScanSettings: TTabSheet;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label23: TLabel;
    Label24: TLabel;
    cbShowUndo: TCheckBox;
    cbCenterOnPopup: TCheckBox;
    EditUpdateInterval: TEdit;
    EditFreezeInterval: TEdit;
    GroupBox1: TGroupBox;
    cbShowAsSigned: TCheckBox;
    cbsimplecopypaste: TCheckBox;
    cbUpdatefoundList: TCheckBox;
    editUpdatefoundInterval: TEdit;
    cbHideAllWindows: TCheckBox;
    btnExcludeProcesses: TButton;
    EditAutoAttach: TEdit;
    cbAlwaysAutoAttach: TCheckBox;
    cbSaveWindowPos: TCheckBox;
    Label3: TLabel;
    Label1: TLabel;
    Label15: TLabel;
    Label21: TLabel;
    combothreadpriority: TComboBox;
    cbFastscan: TCheckBox;
    cbSkip_PAGE_NOCACHE: TCheckBox;
    cbMemImage: TCheckBox;
    cbMemMapped: TCheckBox;
    cbMemPrivate: TCheckBox;
    EditBufsize: TEdit;
    Plugins: TTabSheet;
    CodeFinder: TTabSheet;
    Assembler: TTabSheet;
    cbHandleBreakpoints: TCheckBox;
    replacewithnops: TCheckBox;
    askforreplacewithnops: TCheckBox;
    Extra: TTabSheet;
    TauntOldOsUser: TLabel;
    GroupBox3: TGroupBox;
    cbKernelQueryMemoryRegion: TCheckBox;
    cbKernelReadWriteProcessMemory: TCheckBox;
    cbKernelOpenProcess: TCheckBox;
    cbProcessWatcher: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    tsHotkeys: TTabSheet;
    OpenDialog1: TOpenDialog;
    Unrandomizer: TTabSheet;
    Label5: TLabel;
    edtDefault: TEdit;
    cbIncremental: TCheckBox;
    Panel6: TPanel;
    AboutLabel: TLabel;
    btnCancel: TButton;
    btnOK: TButton;
    frameHotkeyConfig: TframeHotkeyConfig;
    cbProcessIcons: TCheckBox;
    cbProcessIconsOnly: TCheckBox;
    tsTools: TTabSheet;
    Panel2: TPanel;
    cbShowTools: TCheckBox;
    Panel3: TPanel;
    edtApplicationTool: TEdit;
    btnSetToolShortcut: TButton;
    Panel5: TPanel;
    Panel4: TPanel;
    btnToolNew: TButton;
    btnToolDelete: TButton;
    lvTools: TListView;
    lblApplicationTool: TLabel;
    lblShortcut: TLabel;
    lblShortcutText: TLabel;
    lblToolsName: TLabel;
    edtToolsName: TEdit;
    OpenButton: TSpeedButton;
    OpenDialog2: TOpenDialog;
    cbShowMainMenu: TCheckBox;
    cbOldPointerAddMethod: TCheckBox;
    Panel7: TPanel;
    Button5: TButton;
    Button4: TButton;
    Panel8: TPanel;
    Label22: TLabel;
    clbPlugins: TCheckListBox;
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure cbAskIfTableHasLuascriptChange(Sender: TObject);
    procedure cbDontusetempdirChange(Sender: TObject);
    procedure cbDebuggerInterfaceChange(Sender: TObject);
    procedure cbKernelQueryMemoryRegionChange(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure EditBufSizeKeyPress(Sender: TObject; var Key: Char);
    procedure Default1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cbShowDisassemblerClick(Sender: TObject);
    procedure LoadButtonClick(Sender: TObject);
    procedure pcSettingChange(Sender: TObject);
    procedure rbInt3AsBreakpointChange(Sender: TObject);
    procedure replacewithnopsClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure CheckBox2Click(Sender: TObject);
    procedure cbUpdatefoundListClick(Sender: TObject);
    procedure AboutLabelClick(Sender: TObject);
    procedure cbHideAllWindowsClick(Sender: TObject);
    procedure btnExcludeProcessesClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure cbKernelQueryMemoryRegionClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure tvMenuSelectionChange(Sender: TObject; Node: TTreeNode);
    procedure Panel6Resize(Sender: TObject);
    procedure cbProcessIconsClick(Sender: TObject);
    procedure tvMenuSelectionCollapsing(Sender: TObject; Node: TTreeNode;
      var AllowCollapse: Boolean);
    procedure btnSetToolShortcutClick(Sender: TObject);
    procedure cbShowToolsClick(Sender: TObject);
    procedure btnToolNewClick(Sender: TObject);
    procedure lvToolsClick(Sender: TObject);
    procedure edtApplicationToolChange(Sender: TObject);
    procedure btnToolDeleteClick(Sender: TObject);
    procedure edtToolsNameChange(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
  private
    { Private declarations }
    tempstatePopupHide:word;
    temppopupmodifier:dword;
    tempstatePause:word;
    tempPausemodifier:dword;
    tempstateSpeedhack:word;
    tempSpeedhackmodifier:dword;


    tempmodulelist: pchar;
    tempmodulelistsize: integer;
    tempdenylist: boolean;
    tempdenylistglobal: boolean;

    deletedmodules: tstringlist;

    procedure SetAssociations;
  public
    { Public declarations }
    

    tempdonthidelist: array of string;
    temphideall: boolean;
    laststatePopupHide:word;
    lastpopupmodifier:dword;
    laststatePause:word;
    lastPausemodifier:dword;
    laststateSpeedhack:word;
    lastSpeedhackmodifier:dword;
    Loadingsettingsfromregistry: boolean;

    unrandomizersettings: record
                            defaultreturn: integer;
                            incremental: boolean;
                          end;

  published
    property SettingsTreeView: TTreeView read tvMenuSelection;   //just some stuff to make things look nicer. You're not required to use them
    property SettingsPageControl: TPageControl read pcSetting;

  end;

var
  formSettings: TformSettings;



  {$ifdef net}
  IsDebuggerPresentLocation: integer=0;
  {$endif}

implementation

uses
aboutunit,


MainUnit,
MainUnit2,
frmExcludeHideUnit, {
MemoryBrowserFormUnit,}
ModuleSafetyUnit,
frmProcessWatcherUnit,
ConfigUnrandomizerFrm,
CustomTypeHandler,
processlist,
Globals;





procedure decimal(var key: char);
begin
  case key of
    chr(8)   : ;
    chr(16)  : ;
    '0'..'9' : ;
    else key:=chr(0);
  end;
end;


procedure TFormSettings.SetAssociations; //obsolete, done from installer
begin

end;


resourcestring
  strProcessWatcherWillPreventUnloader='Enabling the process watcher will prevent the unloader from working';
  rsYouHavenTSelectedAnyMemoryTypeThisWillResultInChea = 'You haven''t selected any memory type. This will result in Cheat Engine finding NO memory! Are you stupid?';
  rsIsNotAValidInterval = '%s is not a valid interval';
  rsTheScanbufferSizeHasToBeGreaterThan0 = 'The scanbuffer size has to be greater than 0';
  rsTheValueForTheKeypollIntervalIsInvalid = 'the value for the keypoll interval (%s is invalid';
  rsTheValueForTheWaitBetweenHotkeyPressesIsInvalid = 'the value for the wait between hotkey presses (%s is invalid';
  rsPleaseBootWithUnsignedDriversAllowedF8DuringBootOr = 'Please boot with unsigned drivers allowed(F8 during boot), or sign the driver yourself';
  rsRequiresDBVM = '(Requires DBVM)';
  rsThisPluginIsAlreadyLoaded = 'This plugin is already loaded';
  rsIdle = 'Idle';
  rsLowest = 'Lowest';
  rsLower = 'Lower';
  rsNormal = 'Normal';
  rsHigher = 'Higher';
  rsHighest = 'Highest';
  rsTimeCritical = 'TimeCritical';
  rsGeneralSettings = 'General Settings';
  rsTools = 'Tools';
  rsHotkeys = 'Hotkeys';
  rsUnrandomizer = 'Unrandomizer';
  rsScanSettings = 'Scan Settings';
  rsPlugins = 'Plugins';
  rsDebuggerOptions = 'Debugger Options';
  rsExtra = 'Extra';
  rsNoName = 'No Name';
  rsPopupHideCheatEngine = 'Popup/Hide cheat engine';
  rsPauseTheSelectedProcess = 'Pause the selected process';
  rsToggleTheSpeedhack = 'Toggle the speedhack';
  rsSpeedhackSpeed = 'Speedhack speed';
  rsChangeTypeTo = 'Change type to';
  rsBinary = 'Binary';
  rsByte = 'Byte';
  rs2Bytes = '2 Bytes';
  rs4Bytes = '4 Bytes';
  rs8Bytes = '8 Bytes';
  rsFloat = 'Float';
  rsDouble = 'Double';
  rsText = 'Text';
  rsArrayOfByte = 'Array of byte';
  rsNextScan = 'Next Scan';
  rsToggleBetweenFirstLastScanCompare =
    'Toggle between first/last scan compare';
  rsUndoLastScan = 'Undo last scan';
  rsCancelTheCurrentScan = 'Cancel the current scan';
  rsDebugRun = 'Debug->Run';
  rsUnknownInitialValue = 'Unknown Initial Value';
  rsIncreasedValue = 'Increased Value';
  rsDecreasedValue = 'Decreased Value';
  rsChangedValue = 'Changed Value';
  rsUnchangedValue = 'Unchanged Value';
procedure TformSettings.btnOKClick(Sender: TObject);
var processhandle2: Thandle;
    reg: TRegistry;
    bufsize: integer;
    i,j,error: integer;
    ec:dword;
    found:boolean;

    networkupdateinterval,updateinterval,freezeinterval,FoundInterval: integer;
    stacksize: integer;

    dllpath: Tpathspecifier;

    cpu: string;
begin

  {$ifdef cpu64}
  cpu:='64';
  {$else}
  cpu:='32';
  {$endif}

{$ifndef net}

  if cbProcessWatcher.checked and (frmprocesswatcher=nil) then
  begin
    loaddbk32;
    frmprocesswatcher:=tfrmprocesswatcher.Create(mainform); //start the process watcher
  end;


{$endif}

  if not ((cbMemPrivate.checked) or (cbMemImage.Checked) or (cbMemMapped.Checked)) then
    if messagedlg(rsYouHavenTSelectedAnyMemoryTypeThisWillResultInChea, mtWarning, [mbyes, mbno], 0)<>mryes then exit;

  val(edtStacksize.text, stacksize, error);
  if (error<>0) or (stacksize<=0) then raise exception.Create(Format(rsIsNotAValidInterval, [edtStacksize.text]));





  val(editUpdatefoundInterval.Text,foundinterval,error);
  if (error<>0) or (foundinterval<=0) then raise exception.Create(Format(rsIsNotAValidInterval, [editUpdatefoundInterval.Text]));

  val(editupdateinterval.text,updateinterval,error);
  if (error<>0) or (updateinterval<=0) then raise exception.Create(Format(rsIsNotAValidInterval, [editupdateinterval.text]));

  val(editfreezeinterval.text,freezeinterval,error);
  if (error<>0) or (updateinterval<=0) then raise exception.Create(Format(rsIsNotAValidInterval, [editfreezeinterval.text]));


  try bufsize:=StrToInt(editbufsize.text); except bufsize:=1024; end;

  if bufsize=0 then raise exception.create(rsTheScanbufferSizeHasToBeGreaterThan0);

  buffersize:=bufsize*1024;

  mainform.UndoScan.visible:={$ifdef net}false{$else}cbshowundo.checked{$endif};



  //save to the registry
  reg:=Tregistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('\Software\Cheat Engine',true) then
    begin
      //write the settings
      reg.WriteInteger('Saved Stacksize', stacksize);

      reg.writebool('Show processlist in mainmenu', cbShowProcesslist.checked);
      mainform.Process1.Visible:=cbShowProcesslist.checked;


      reg.WriteBool('Undo',cbshowundo.checked);
      reg.WriteInteger('ScanThreadpriority',combothreadpriority.itemindex);
      case combothreadpriority.itemindex of
        0: scanpriority:=tpIdle;
        1: scanpriority:=tpLowest;
        2: scanpriority:=tpLower;
        3: scanpriority:=tpLower;
        4: scanpriority:=tpNormal;
        5: scanpriority:=tpHigher;
        6: scanpriority:=tpHighest;
        7: scanpriority:=tpTimeCritical;
      end;






      reg.WriteBool('Show all windows on taskbar',cbShowallWindows.checked);
      if cbShowallWindows.checked then
        Application.TaskBarBehavior:=tbMultiButton
      else
        Application.TaskBarBehavior:=tbSingleButton;

      AllIncludesCustomType:=cbAllIncludesCustomType.checked;
      reg.writebool('All includes custom types', cbAllIncludesCustomType.checked);


      reg.writebool('Can Step Kernelcode',cbCanStepKernelcode.checked);

      reg.WriteInteger('Buffersize',bufsize);
      reg.WriteBool('Center on popup',cbCenterOnPopup.checked);
      reg.WriteInteger('Update interval',updateinterval);
      reg.WriteInteger('Freeze interval',freezeinterval);
      reg.writebool('Show values as signed',cbShowAsSigned.checked);


      reg.WriteBool('Replace incomplete opcodes with NOPS',replacewithnops.checked);
      reg.WriteBool('Ask for replace with NOPS',askforreplacewithnops.checked);
      reg.WriteBool('Use Anti-debugdetection',checkbox1.checked);
      reg.WriteBool('Override existing bp''s',cbOverrideExistingBPs.checked);
      BPOverride:=cbOverrideExistingBPs.checked;


      reg.WriteBool('Handle unhandled breakpoints',cbhandlebreakpoints.Checked);
      reg.WriteBool('Fastscan on by default',cbFastscan.checked);

      reg.WriteBool('Hardware breakpoints', rbDebugAsBreakpoint.checked);
      reg.WriteBool('Software breakpoints', rbInt3AsBreakpoint.checked);
      reg.Writebool('Exception breakpoints', rbPageExceptions.checked);

      reg.WriteBool('Update Foundaddress list',cbUpdatefoundList.checked);
      reg.WriteInteger('Update Foundaddress list Interval',foundinterval);

      reg.WriteBool('Simple copy/paste',cbsimplecopypaste.checked);
      reg.WriteString('AutoAttach',EditAutoAttach.text);
      reg.writebool('Always AutoAttach', cbAlwaysAutoAttach.checked);

      reg.WriteBool('Ask if table has lua script',cbAskIfTableHasLuascript.Checked);
      reg.WriteBool('Always run script',cbAlwaysRunScript.Checked);





      {$ifndef net}
      mainform.UpdateFoundlisttimer.Interval:=foundinterval;
      {$endif}

      reg.WriteBool('Save window positions',cbSaveWindowPos.checked);
      reg.WriteBool('Show main menu',cbShowMainMenu.Checked);
      reg.WriteBool('Get process icons',cbProcessIcons.Checked);
      GetProcessIcons:=cbProcessIcons.Checked;

      reg.WriteBool('Only show processes with icon',cbProcessIconsOnly.Checked);
      ProcessesWithIconsOnly:=cbProcessIconsOnly.Checked;

      reg.WriteBool('Pointer appending', cbOldPointerAddMethod.checked);

      reg.writebool('skip PAGE_NOCACHE',cbSkip_PAGE_NOCACHE.Checked);
      reg.WriteBool('Hide all windows',cbHideAllWindows.checked);
      reg.WriteBool('Really hide all windows',temphideall);


      //save donthidelist
      {$ifndef net}
      setlength(donthidelist,length(tempdonthidelist));
      for i:=0 to length(tempdonthidelist)-1 do
      begin
        donthidelist[i]:=tempdonthidelist[i];
        reg.writestring('Do not hide '+IntToStr(i),tempdonthidelist[i]);
      end;

      //end
      reg.writestring('Do not hide '+IntToStr(length(tempdonthidelist)),'');
      reg.WriteBool('MEM_PRIVATE',cbMemPrivate.checked);
      reg.WriteBool('MEM_IMAGE',cbMemImage.Checked);
      reg.WriteBool('MEM_MAPPED',cbMemMapped.Checked);
      onlyfront:=not temphideall;




      //check the module list

      if frmModuleSafety<>nil then //modified
      begin
        freemem(modulelist);
        modulelist:=tempmodulelist;
        modulelistsize:=tempmodulelistsize;
        tempmodulelist:=nil;
        denylist:=tempdenylist;
        denylistglobal:=tempdenylistglobal;

        reg.WriteBinaryData('Module List',ModuleList^,modulelistsize);
        reg.writeInteger('modulelistsize',modulelistsize);
        reg.WriteBool('Global Denylist',DenyListGlobal);
        reg.WriteBool('ModuleList as Denylist',DenyList);
      end;


      try
        reg.WriteInteger('hotkey poll interval',strtoint(frameHotkeyConfig.edtKeypollInterval.text));
        hotkeyPollInterval:=strtoint(frameHotkeyConfig.edtKeypollInterval.text);
      except
        raise exception.Create(Format(rsTheValueForTheKeypollIntervalIsInvalid, [frameHotkeyConfig.edtKeypollInterval.text]));
      end;

      try
        reg.WriteInteger('Time between hotkeypress',strtoint(frameHotkeyConfig.edtHotkeyDelay.text));
        hotkeyIdletime:=strtoint(frameHotkeyConfig.edtHotkeyDelay.text);
      except
        raise exception.Create(Format(rsTheValueForTheWaitBetweenHotkeyPressesIsInvalid, [frameHotkeyConfig.edtHotkeyDelay.text]));
      end;





        //save the hotkeylist
        reg.WriteBinaryData('Show Cheat Engine Hotkey',frameHotkeyConfig.newhotkeys[0][0],10);
        reg.WriteBinaryData('Pause process Hotkey',frameHotkeyConfig.newhotkeys[1][0],10);
        reg.WriteBinaryData('Toggle speedhack Hotkey',frameHotkeyConfig.newhotkeys[2][0],10);


        reg.WriteFloat('Speedhack 1 speed',frameHotkeyConfig.newspeedhackspeed1.speed);
        reg.WriteFloat('Speedhack 2 speed',frameHotkeyConfig.newspeedhackspeed2.speed);
        reg.WriteFloat('Speedhack 3 speed',frameHotkeyConfig.newspeedhackspeed3.speed);
        reg.WriteFloat('Speedhack 4 speed',frameHotkeyConfig.newspeedhackspeed4.speed);
        reg.WriteFloat('Speedhack 5 speed',frameHotkeyConfig.newspeedhackspeed5.speed);

        mainunit2.speedhackspeed1:=frameHotkeyConfig.newspeedhackspeed1;
        mainunit2.speedhackspeed2:=frameHotkeyConfig.newspeedhackspeed2;
        mainunit2.speedhackspeed3:=frameHotkeyConfig.newspeedhackspeed3;
        mainunit2.speedhackspeed4:=frameHotkeyConfig.newspeedhackspeed4;
        mainunit2.speedhackspeed5:=frameHotkeyConfig.newspeedhackspeed5;

        reg.WriteBinaryData('Set Speedhack speed 1 Hotkey',frameHotkeyConfig.newhotkeys[3][0],10);
        reg.WriteBinaryData('Set Speedhack speed 2 Hotkey',frameHotkeyConfig.newhotkeys[4][0],10);
        reg.WriteBinaryData('Set Speedhack speed 3 Hotkey',frameHotkeyConfig.newhotkeys[5][0],10);
        reg.WriteBinaryData('Set Speedhack speed 4 Hotkey',frameHotkeyConfig.newhotkeys[6][0],10);
        reg.WriteBinaryData('Set Speedhack speed 5 Hotkey',frameHotkeyConfig.newhotkeys[7][0],10);

        reg.WriteBinaryData('Increase Speedhack speed',frameHotkeyConfig.newhotkeys[8][0],10);
        reg.WriteFloat('Increase Speedhack delta',frameHotkeyConfig.speedupdelta);

        reg.WriteBinaryData('Decrease Speedhack speed',frameHotkeyConfig.newhotkeys[9][0],10);
        reg.WriteFloat('Decrease Speedhack delta',frameHotkeyConfig.slowdowndelta);

        mainunit2.speedupdelta:=frameHotkeyConfig.speedupdelta;
        mainunit2.slowdowndelta:=frameHotkeyConfig.slowdowndelta;

        reg.WriteBinaryData('Binary Hotkey',frameHotkeyConfig.newhotkeys[10][0],10);
        reg.WriteBinaryData('Byte Hotkey',frameHotkeyConfig.newhotkeys[11][0],10);
        reg.WriteBinaryData('2 Bytes Hotkey',frameHotkeyConfig.newhotkeys[12][0],10);
        reg.WriteBinaryData('4 Bytes Hotkey',frameHotkeyConfig.newhotkeys[13][0],10);
        reg.WriteBinaryData('8 Bytes Hotkey',frameHotkeyConfig.newhotkeys[14][0],10);
        reg.WriteBinaryData('Float Hotkey',frameHotkeyConfig.newhotkeys[15][0],10);
        reg.WriteBinaryData('Double Hotkey',frameHotkeyConfig.newhotkeys[16][0],10);
        reg.WriteBinaryData('Text Hotkey',frameHotkeyConfig.newhotkeys[17][0],10);
        reg.WriteBinaryData('Array of Byte Hotkey',frameHotkeyConfig.newhotkeys[18][0],10);
        reg.WriteBinaryData('New Scan Hotkey',frameHotkeyConfig.newhotkeys[19][0],10);
        reg.WriteBinaryData('New Scan-Exact Value',frameHotkeyConfig.newhotkeys[20][0],10);
        reg.WriteBinaryData('Unknown Initial Value Hotkey',frameHotkeyConfig.newhotkeys[21][0],10);
        reg.WriteBinaryData('Next Scan-Exact Value',frameHotkeyConfig.newhotkeys[22][0],10);
        reg.WriteBinaryData('Increased Value Hotkey',frameHotkeyConfig.newhotkeys[23][0],10);
        reg.WriteBinaryData('Decreased Value Hotkey',frameHotkeyConfig.newhotkeys[24][0],10);
        reg.WriteBinaryData('Changed Value Hotkey',frameHotkeyConfig.newhotkeys[25][0],10);
        reg.WriteBinaryData('Unchanged Value Hotkey',frameHotkeyConfig.newhotkeys[26][0],10);
        reg.WriteBinaryData('Same as first scan Hotkey',frameHotkeyConfig.newhotkeys[27][0],10);

        reg.WriteBinaryData('Undo Last scan Hotkey',frameHotkeyConfig.newhotkeys[28][0],10);
        reg.WriteBinaryData('Cancel scan Hotkey',frameHotkeyConfig.newhotkeys[29][0],10);
        reg.WriteBinaryData('Debug->Run Hotkey',frameHotkeyConfig.newhotkeys[30][0],10);


        //apply these hotkey changes
        for i:=0 to 30 do
        begin
          found:=false;

          for j:=0 to length(hotkeythread.hotkeylist)-1 do
          begin
            if (hotkeythread.hotkeylist[j].id=i) and (hotkeythread.hotkeylist[j].handler2) then
            begin
              //found it
              hotkeythread.hotkeylist[j].keys:=frameHotkeyConfig.newhotkeys[i];
              found:=true;
              break;
            end;
          end;

          if not found then //add it
          begin
            j:=length(hotkeythread.hotkeylist);
            setlength(hotkeythread.hotkeylist,j+1);
            hotkeythread.hotkeylist[j].keys:=frameHotkeyConfig.newhotkeys[i];
            hotkeythread.hotkeylist[j].windowtonotify:=mainform.Handle;
            hotkeythread.hotkeylist[j].id:=i;
            hotkeythread.hotkeylist[j].handler2:=true;
          end;

          checkkeycombo(frameHotkeyConfig.newhotkeys[i]);
        end;





      {$endif}
      dontusetempdir:=cbDontusetempdir.checked;
      tempdiralternative:=trim(edtTempScanFolder.text);

      tempdiralternative:=IncludeTrailingPathDelimiter(tempdiralternative);


      reg.WriteBool('Don''t use tempdir',dontusetempdir);
      reg.WriteString('Scanfolder',tempdiralternative);


      reg.WriteBool('Use dbk32 QueryMemoryRegionEx',cbKernelQueryMemoryRegion.checked);
      reg.WriteBool('Use dbk32 ReadWriteProcessMemory',cbKernelReadWriteProcessMemory.checked);
      reg.WriteBool('Use dbk32 OpenProcess',cbKernelOpenProcess.checked);

      reg.WriteBool('Use Processwatcher',cbProcessWatcher.checked);
      reg.WriteBool('Use VEH Debugger',cbUseVEHDebugger.checked);
      reg.WriteBool('VEH Real context on thread creation event', cbVEHRealContextOnThreadCreation.checked);
      VEHRealContextOnThreadCreation:=cbVEHRealContextOnThreadCreation.checked;


      reg.WriteBool('Use Windows Debugger',cbUseWindowsDebugger.checked);
      reg.WriteBool('Use Kernel Debugger',cbKdebug.checked);
      reg.WriteBool('Use Global Debug Routines',cbGlobalDebug.checked);

      waitafterguiupdate:=cbWaitAfterGuiUpdate.checked;
      reg.WriteBool('Wait After Gui Update', waitafterguiupdate);



      unrandomizersettings.defaultreturn:=strtoint(edtdefault.Text);
      unrandomizersettings.incremental:=cbincremental.Checked;
      reg.WriteInteger('Unrandomizer: default value',unrandomizersettings.defaultreturn);
      reg.WriteBool('Unrandomizer: incremental',unrandomizersettings.incremental);

      reg.writebool('Show tools menu', cbShowTools.checked);
      mainform.ools1.Visible:=cbShowTools.checked;

    end;




{$ifndef net}
    //save the tools hotkeys
    reg.DeleteKey('\Software\Cheat Engine\Tools');
    if Reg.OpenKey('\Software\Cheat Engine\Tools',true) then
    begin
      for i:=0 to lvTools.Items.Count-1 do
      begin
        reg.WriteString(format('%.8x A',[i]),lvTools.Items[i].caption);
        reg.WriteString(format('%.8x B',[i]),lvTools.Items[i].subitems[0]);
        reg.WriteInteger(format('%.8x C',[i]),ptrUint(lvTools.Items[i].data));
      end;
    end;
    UpdateToolsMenu;

    for i:=0 to deletedmodules.Count-1 do
    begin
      j:=pluginhandler.GetPluginID(deletedmodules[i]);
      if j<>-1 then
        pluginhandler.DisablePlugin(j);
    end;

    //save the plugins
    reg.DeleteKey('\Software\Cheat Engine\Plugins'+cpu);
    if Reg.OpenKey('\Software\Cheat Engine\Plugins'+cpu,true) then
    begin
      for i:=0 to clbplugins.Count-1 do
      begin
        dllpath:=Tpathspecifier(clbplugins.Items.Objects[i]);

        reg.WriteString(format('%.8x A',[i]),dllpath.path);
        reg.WriteBool(format('%.8x B',[i]),clbplugins.Checked[i]);
      end;
    end;



    for i:=0 to clbplugins.Count-1 do
    begin
      dllpath:=Tpathspecifier(clbplugins.Items.Objects[i]);
      if dllpath<>nil then
      begin

        j:=pluginhandler.GetPluginID(dllpath.path);

        if j=-1 then //not loaded yet
          j:=pluginhandler.LoadPlugin(dllpath.path);

        if clbplugins.Checked[i] then
        begin
          //at least load it if it is loadable

          pluginhandler.EnablePlugin(j);
        end
        else
          pluginhandler.DisablePlugin(j);
      end;
    end;
{$endif}



  finally
    reg.CloseKey;
    reg.free;
  end;



  SetAssociations;


  {$ifndef net}
  mainform.FreezeTimer.Interval:=freezeinterval;
  mainform.UpdateTimer.Interval:=updateinterval;
  {$else}
  mainform.FreezeTimer.Interval:=freezeinterval;
  mainform.UpdateTimer.Interval:=networkupdateinterval;
  {$endif}

  savedStackSize:=stacksize;

  Skip_PAGE_NOCACHE:=cbSkip_PAGE_NOCACHE.Checked;

  {$ifndef net}
  Scan_MEM_PRIVATE:=cbMemPrivate.checked;
  Scan_MEM_IMAGE:=cbMemImage.Checked;
  Scan_MEM_MAPPED:=cbMemMapped.Checked;
  {$endif}


  if rbDebugAsBreakpoint.checked then
    preferedBreakpointMethod:=bpmDebugRegister
  else
  if rbInt3AsBreakpoint.checked then
    preferedBreakpointMethod:=bpmInt3
  else
  if rbPageExceptions.checked then
    preferedBreakpointMethod:=bpmException;

  laststatePopupHide:=tempstatepopuphide;
  lastpopupmodifier:=temppopupmodifier;
  laststatePause:=tempstatepause;
  lastPausemodifier:=temppausemodifier;
  laststateSpeedhack:=tempstatespeedhack;
  lastSpeedhackmodifier:=tempspeedhackmodifier;

  mainform.autoattachlist.DelimitedText:=formsettings.EditAutoAttach.Text;

  if cbShowMainMenu.Checked then
    mainform.Menu:=mainform.MainMenu1
  else
    mainform.Menu:=nil;

  modalresult:=mrok;

end;

procedure TformSettings.btnCancelClick(Sender: TObject);
begin

end;

procedure TformSettings.cbAskIfTableHasLuascriptChange(Sender: TObject);
begin
  cbAlwaysRunScript.enabled:=not cbAskIfTableHasLuascript.checked;
end;

procedure TformSettings.cbDontusetempdirChange(Sender: TObject);
begin
  label2.enabled:=cbDontusetempdir.checked;
  edtTempScanFolder.enabled:=cbDontusetempdir.checked;
  loadButton.enabled:=cbDontusetempdir.checked;
end;

procedure TformSettings.cbDebuggerInterfaceChange(Sender: TObject);
begin
  rbInt3AsBreakpoint.enabled:=not cbKDebug.checked;

  if cbUseVEHDebugger.Checked then
    pcDebugConfig.ActivePageIndex:=0
  else
  if cbUseWindowsDebugger.checked then
    pcDebugConfig.ActivePageIndex:=1
  else
  if cbKDebug.checked then
  begin
    rbDebugAsBreakpoint.checked:=true;
    pcDebugConfig.ActivePageIndex:=2;
  end;


  rbPageExceptions.enabled:=not cbKDebug.checked; //currently the kerneldebugger doesn't handle pageexceptions yet (can be added, but not right now)
  if rbPageExceptions.checked and not rbPageExceptions.enabled then
    rbDebugAsBreakpoint.checked:=true;
end;

procedure TformSettings.cbKernelQueryMemoryRegionChange(Sender: TObject);
begin

end;

procedure TformSettings.CheckBox1Change(Sender: TObject);
begin
  PreventDebuggerDetection:=checkbox1.checked;
end;



procedure TformSettings.EditBufSizeKeyPress(Sender: TObject;
  var Key: Char);
begin
  decimal(key);
end;

procedure TformSettings.Default1Click(Sender: TObject);
begin
  editbufsize.Text:='512';
end;

procedure TformSettings.FormDestroy(Sender: TObject);
begin
  formsettings:=nil;
end;

procedure TformSettings.FormShow(Sender: TObject);
  function CheckAssociation(ext: string):boolean;
  var  reg: TRegistry;
       temp: string;
  begin
    reg := TRegistry.Create;
    reg.RootKey := HKEY_CLASSES_ROOT;
    reg.LazyWrite := false;

    try
      reg.OpenKey(ext+'\shell\open\command',false);
    except
      result:=false;
      reg.free;
      exit;
    end;

    temp:=reg.ReadString('');
    if temp<>application.ExeName+' "%1"' then
    begin
      result:=false;
      reg.CloseKey;
      reg.free;
      exit;
    end;

    result:=true;
  end;
  var reg: TRegistry;
  i: integer;
begin

  tempstatepopuphide:=laststatePopupHide;
  temppopupmodifier:=lastpopupmodifier;
  tempstatepause:=laststatePause;
  temppausemodifier:=lastPausemodifier;
  tempstatespeedhack:=laststateSpeedhack;
  tempspeedhackmodifier:=lastSpeedhackmodifier;

  {$ifndef net}
  setlength(tempdonthidelist,length(donthidelist));
  for i:=0 to length(donthidelist)-1 do
    tempdonthidelist[i]:=donthidelist[i];
  {$endif net}


  label1.Enabled:=not mainform.btnNextScan.enabled;
  editbufsize.enabled:=not mainform.btnNextScan.enabled;

  //load the settings from the register and apply them to this window


  //fill hotkey list
  for i:=0 to length(hotkeythread.hotkeylist)-1 do
    if hotkeythread.hotkeylist[i].handler2 and inrange(hotkeythread.hotkeylist[i].id, 0, 30) then
      framehotkeyconfig.newhotkeys[hotkeythread.hotkeylist[i].id]:=hotkeythread.hotkeylist[i].keys;

  framehotkeyconfig.newspeedhackspeed1:=speedhackspeed1;
  framehotkeyconfig.newspeedhackspeed2:=speedhackspeed2;
  framehotkeyconfig.newspeedhackspeed3:=speedhackspeed3;
  framehotkeyconfig.newspeedhackspeed4:=speedhackspeed4;
  framehotkeyconfig.newspeedhackspeed5:=speedhackspeed5;

  framehotkeyconfig.speedupdelta:=speedupdelta;
  framehotkeyconfig.slowdowndelta:=slowdowndelta;


  cbDebuggerInterfaceChange(nil);



 // GroupBox2.top:=rbgDebuggerInterface.top+rbgDebuggerInterface.height+4;
end;

procedure TformSettings.cbShowDisassemblerClick(Sender: TObject);
begin

end;

procedure TformSettings.LoadButtonClick(Sender: TObject);
begin
  if SelectDirectoryDialog1.Execute then
    edtTempScanFolder.text:=SelectDirectoryDialog1.FileName;
end;

procedure TformSettings.pcSettingChange(Sender: TObject);
begin

end;

procedure TformSettings.rbInt3AsBreakpointChange(Sender: TObject);
begin

end;

procedure TformSettings.replacewithnopsClick(Sender: TObject);
begin
  askforreplacewithnops.Enabled:=replacewithnops.Checked;
end;

procedure TformSettings.CheckBox1Click(Sender: TObject);
begin

end;

procedure TformSettings.CheckBox2Click(Sender: TObject);
begin

end;

procedure TformSettings.cbUpdatefoundListClick(Sender: TObject);
begin
  if cbUpdatefoundList.Checked then
  begin
    label18.Enabled:=true;
    editUpdatefoundInterval.Enabled:=true;
    Label19.Enabled:=true;
  end
  else
  begin
    label18.Enabled:=false;
    editUpdatefoundInterval.Enabled:=false;
    Label19.Enabled:=false;
  end;
end;

procedure TformSettings.AboutLabelClick(Sender: TObject);
begin

  with tabout.create(self) do
  begin
    showmodal;
    free;
  end;

end;

procedure TformSettings.cbHideAllWindowsClick(Sender: TObject);
begin
  btnExcludeProcesses.enabled:=cbHideallWindows.Checked;
end;

procedure TformSettings.btnExcludeProcessesClick(Sender: TObject);
begin
  {$ifndef net}

  with tfrmExcludeHide.create(self) do
  begin
    showmodal;
    free;
  end;
  {$endif}
end;

procedure TformSettings.FormCreate(Sender: TObject);
var i: integer;
begin
  tvMenuSelection.Items[0].Data:=GeneralSettings;
  tvMenuSelection.Items[1].Data:=tsTools;
  tvMenuSelection.Items[2].Data:=tsHotkeys;
  tvMenuSelection.Items[3].Data:=Unrandomizer;
  tvMenuSelection.Items[4].Data:=ScanSettings;
  tvMenuSelection.Items[5].Data:=Plugins;
  tvMenuSelection.Items[6].Data:=self.Assembler;
  tvMenuSelection.Items[7].Data:=Extra;


  pcSetting.ShowTabs:=false;





  combothreadpriority.Items.Clear;
  with combothreadpriority.items do
  begin
    add(rsIdle);
    add(rsLowest);
    add(rsLower);
    add(rsNormal);
    add(rsHigher);
    add(rsHighest);
    add(rsTimeCritical);
  end;

  combothreadpriority.ItemIndex:=4;


  with frameHotkeyConfig.ListBox1.items do
  begin
    clear;
    add(rsPopupHideCheatEngine);
    add(rsPauseTheSelectedProcess);
    add(rsToggleTheSpeedhack);
    add(rsSpeedhackSpeed+' 1');
    add(rsSpeedhackSpeed+' 2');
    add(rsSpeedhackSpeed+' 3');
    add(rsSpeedhackSpeed+' 4');
    add(rsSpeedhackSpeed+' 5');
    add(rsSpeedhackSpeed+' +');
    add(rsSpeedhackSpeed+' -');
    add(rsChangeTypeTo+' '+rsBinary);
    add(rsChangeTypeTo+' '+rsByte);
    add(rsChangeTypeTo+' '+rs2Bytes);
    add(rsChangeTypeTo+' '+rs4Bytes);
    add(rsChangeTypeTo+' '+rs8Bytes);
    add(rsChangeTypeTo+' '+rsFloat);
    add(rsChangeTypeTo+' '+rsDouble);
    add(rsChangeTypeTo+' '+rsText);
    add(rsChangeTypeTo+' '+rsArrayOfByte);
    add(strNewScan);
    add(strNewScan+'-'+strexactvalue);
    add(strNewScan+'-'+rsUnknownInitialValue);
    add(rsNextScan+'-'+strexactvalue);
    add(rsNextScan+'-'+rsIncreasedValue);
    add(rsNextScan+'-'+rsDecreasedValue);
    add(rsNextScan+'-'+rsChangedValue);
    add(rsNextScan+'-'+rsUnchangedValue);
    add(rsToggleBetweenFirstLastScanCompare);
    add(rsUndoLastScan);
    add(rsCancelTheCurrentScan);
    add(rsDebugRun);
  end;

  tvMenuSelection.Items[0].Text:=rsGeneralSettings;
  tvMenuSelection.Items[1].Text:=rsTools;
  tvMenuSelection.Items[2].Text:=rsHotkeys;
  tvMenuSelection.Items[3].Text:=rsUnrandomizer;
  tvMenuSelection.Items[4].Text:=rsScanSettings;
  tvMenuSelection.Items[5].Text:=rsPlugins;
  tvMenuSelection.Items[6].Text:=rsDebuggerOptions;
  tvMenuSelection.Items[7].Text:=rsExtra;



  aboutlabel.left:=aboutlabel.parent.ClientWidth-aboutlabel.width;
  aboutlabel.top:=aboutlabel.parent.clientheight-aboutlabel.height;

  //set the default popup
  laststatePopupHide:=vk_next;
  lastpopupmodifier:=MOD_CONTROL or MOD_ALT;

  laststatepause:=ord('P');
  lastpausemodifier:=MOD_CONTROL or MOD_ALT;

  laststateSpeedhack:=ord('S');
  laststateSpeedhack:=MOD_CONTROL or MOD_ALT;

  deletedmodules:=TStringlist.Create;


  //64-bit check
  if is64bitos then
  begin
    TauntOldOsUser.Visible:=true;
    TauntOldOsUser.Caption:=rsPleaseBootWithUnsignedDriversAllowedF8DuringBootOr;



    cbKdebug.Enabled:=isRunningDBVM or isDBVMCapable;

    cbKdebug.Caption:=cbKdebug.Caption+' '+rsRequiresDBVM;
    if not cbKdebug.Enabled then
      cbKdebug.checked:=false;


  end;


  //make the tabs invisible

  for i:=0 to pcSetting.PageCount-1 do
    pcSetting.Pages[i].TabVisible:=false;

  pcSetting.ActivePageIndex:=0;

  for i:=0 to pcDebugConfig.PageCount-1 do
    pcDebugConfig.Pages[i].TabVisible:=false;




  tvMenuSelection.FullExpand;
end;

procedure TformSettings.cbKernelQueryMemoryRegionClick(Sender: TObject);
begin
  if (cbKernelQueryMemoryRegion.Checked) or (cbKernelReadWriteProcessMemory.Checked) then
  begin
    cbKernelOpenProcess.Checked:=true;
    cbKernelOpenProcess.Enabled:=false;
  end
  else cbKernelOpenProcess.Enabled:=true;

end;

procedure TformSettings.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  deletedmodules.Clear;
end;




procedure TformSettings.Button4Click(Sender: TObject);
var pluginname: string;
    fullpath: Tpathspecifier;
    i: integer;
    s: string;
begin
{$ifndef net}

  if opendialog1.Execute then
  begin
    s:=uppercase(ExtractFileName(opendialog1.FileName));
    for i:=0 to clbplugins.count-1 do
      if uppercase(extractfilename(Tpathspecifier(clbplugins.Items.Objects[i]).path))=s then
        raise exception.Create(rsThisPluginIsAlreadyLoaded);

    pluginname:=pluginhandler.GetPluginName(opendialog1.FileName);
    fullpath:=Tpathspecifier.Create;
    fullpath.path:=opendialog1.filename;
    clbPlugins.Items.AddObject(extractfilename(opendialog1.FileName)+':'+pluginname,fullpath);
  end;
{$endif}
end;

procedure TformSettings.Button5Click(Sender: TObject);
var modulename: string;
  dllpath: Tpathspecifier;
  pluginid: integer;
begin

  if clbplugins.ItemIndex<>-1 then
  begin
    dllpath:=Tpathspecifier(clbplugins.Items.Objects[clbplugins.ItemIndex]);
    modulename:=extractfilename(dllpath.path);
    deletedmodules.add(modulename);

    clbPlugins.Items.Delete(clbplugins.ItemIndex);




    pluginid:=pluginhandler.GetPluginID(dllpath.path);
    pluginhandler.UnloadPlugin(pluginid);

    dllpath.Free;
  end;

end;

procedure TformSettings.tvMenuSelectionChange(Sender: TObject;
  Node: TTreeNode);
begin
  if node.Data<>nil then
    pcSetting.ActivePage:=TTabSheet(node.data);
end;

procedure TformSettings.Panel6Resize(Sender: TObject);
begin
  btnOK.Left:=btnOK.parent.ClientWidth div 2 - btnOK.Width - 10;
  btnCancel.Left:=btnCancel.parent.ClientWidth div 2 + 10;
end;

procedure TformSettings.cbProcessIconsClick(Sender: TObject);
begin
  cbProcessIconsOnly.Enabled:=cbProcessIcons.Checked;
  if not cbProcessIcons.Checked then cbProcessIconsOnly.Checked:=false;
end;

procedure TformSettings.tvMenuSelectionCollapsing(Sender: TObject;
  Node: TTreeNode; var AllowCollapse: Boolean);
begin
  AllowCollapse:=false;
end;

procedure TformSettings.btnSetToolShortcutClick(Sender: TObject);
var x: tshortcut;
begin

  if lvtools.Selected=nil then exit;

  with TFormHotkey.Create(self) do
  begin
    if ShowModal=mrok then
    begin
      x:=key;

      if (modifier and MOD_ALT)>0 then
        x:=x or scAlt;

      if (modifier and MOD_CONTROL)>0 then
        x:=x or scCtrl;

      if (modifier and MOD_SHIFT)>0 then
        x:=x or scShift;

      lblShortcutText.caption:=ShortCutToText(x);
      lvtools.Selected.Data:=pointer(ptrUint(x));
      lvtools.Selected.SubItems[1]:=lblShortcutText.caption;
    end;

    free;
  end;
end;

procedure TformSettings.cbShowToolsClick(Sender: TObject);
begin
  lvTools.enabled:=cbShowTools.Checked;
  lblToolsName.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  edtToolsName.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  lblApplicationTool.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  edtApplicationTool.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  OpenButton.Enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  lblShortcut.enabled:= cbShowTools.Checked and (lvtools.Selected<>nil);
  lblShortcutText.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  btnSetToolShortcut.enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);
  btnToolNew.enabled:=cbShowTools.Checked;
  btnToolDelete.Enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);

  if (lvtools.Selected<>nil) then
  begin
    edtToolsName.Text:=lvtools.Selected.Caption;
    edtApplicationTool.Text:=lvtools.Selected.SubItems[0];
    lblShortcutText.caption:=lvtools.Selected.SubItems[1];
  end;

end;

procedure TformSettings.btnToolNewClick(Sender: TObject);
var li:tlistitem;
begin
  li:=lvTools.Items.Add;
  li.Data:=nil;
  li.Caption:=rsNoName;
  li.SubItems.Add('');
  li.SubItems.Add('');
  li.Selected:=true;
  lvTools.OnClick(lvTools);


  edtToolsName.SetFocus;
  edtToolsName.SelectAll;
end;

procedure TformSettings.lvToolsClick(Sender: TObject);
begin
  lblToolsName.enabled:=lvtools.Selected<>nil;
  edtToolsName.enabled:=lvtools.Selected<>nil;
  lblApplicationTool.enabled:=lvtools.Selected<>nil;
  edtApplicationTool.enabled:=lvtools.Selected<>nil;
  lblShortcut.enabled:= lvtools.Selected<>nil;
  lblShortcutText.enabled:=lvtools.Selected<>nil;
  btnSetToolShortcut.enabled:=lvtools.Selected<>nil;
  btnToolDelete.Enabled:=lvtools.Selected<>nil;
  OpenButton.Enabled:=cbShowTools.Checked and (lvtools.Selected<>nil);

  if lvtools.Selected<>nil then
  begin
    edtToolsName.Text:=lvtools.Selected.Caption;
    edtApplicationTool.Text:=lvtools.Selected.SubItems[0];
    lblShortcutText.caption:=lvtools.Selected.SubItems[1];
    edtToolsName.SetFocus;
  end;
end;

procedure TformSettings.edtApplicationToolChange(Sender: TObject);
begin
  lvtools.Selected.subitems[0]:=edtApplicationTool.text;
end;

procedure TformSettings.btnToolDeleteClick(Sender: TObject);
begin
  if lvTools.Selected<>nil then
    lvTools.Selected.Delete;

  lvTools.OnClick(lvTools); //refresh
end;

procedure TformSettings.edtToolsNameChange(Sender: TObject);
begin
  lvtools.Selected.Caption:=edtToolsName.text;
end;

procedure TformSettings.OpenButtonClick(Sender: TObject);
begin
  if opendialog2.Execute then
    edtApplicationTool.Text:=opendialog2.FileName;
end;

initialization
  {$i formsettingsunit.lrs}

end.


