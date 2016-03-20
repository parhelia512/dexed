unit ce_libmaneditor;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Menus, ComCtrls, Buttons, LazFileUtils, strutils, fphttpclient, StdCtrls,
  ce_widget, ce_interfaces, ce_nativeproject, ce_dmdwrap, ce_common, ce_dialogs,
  ce_sharedres, process, ce_dubproject, ce_observer, ce_dlang, ce_stringrange;

type

  TDubPackageQueryForm = class(TForm)
  private
    cbb: TComboBox;
    function getText: string;
    procedure getList(sender: TObject);
  public
    class function showAndWait(out value: string): TModalResult; static;
    constructor Create(TheOwner: TComponent); override;
    property text: string read getText;
  end;

  { TCELibManEditorWidget }
  TCELibManEditorWidget = class(TCEWidget, ICEProjectObserver)
    btnOpenProj: TBitBtn;
    btnMoveDown: TBitBtn;
    btnMoveUp: TBitBtn;
    btnReg: TBitBtn;
    btnDubFetch: TBitBtn;
    btnSelFile: TBitBtn;
    btnAddLib: TBitBtn;
    btnRemLib: TBitBtn;
    btnEditAlias: TBitBtn;
    btnSelfoldOfFiles: TBitBtn;
    btnSelRoot: TBitBtn;
    btnSelProj: TBitBtn;
    List: TListView;
    Panel1: TPanel;
    procedure btnAddLibClick(Sender: TObject);
    procedure btnDubFetchClick(Sender: TObject);
    procedure btnEditAliasClick(Sender: TObject);
    procedure btnOpenProjClick(Sender: TObject);
    procedure btnRegClick(Sender: TObject);
    procedure btnRemLibClick(Sender: TObject);
    procedure btnSelFileClick(Sender: TObject);
    procedure btnSelfoldOfFilesClick(Sender: TObject);
    procedure btnSelProjClick(Sender: TObject);
    procedure btnSelRootClick(Sender: TObject);
    procedure btnMoveUpClick(Sender: TObject);
    procedure btnMoveDownClick(Sender: TObject);
    procedure ListEdited(Sender: TObject; Item: TListItem; var AValue: string);
    procedure ListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean
      );
  private
    fProj: ICECommonProject;
    procedure updateButtonsState;
    procedure projNew(aProject: ICECommonProject);
    procedure projChanged(aProject: ICECommonProject);
    procedure projClosing(aProject: ICECommonProject);
    procedure projFocused(aProject: ICECommonProject);
    procedure projCompiling(aProject: ICECommonProject);
    procedure projCompiled(aProject: ICECommonProject; success: boolean);
    //
    procedure dataToGrid;
    procedure gridToData;
  protected
    procedure DoShow; override;
  public
    constructor Create(aOwner: TComponent); override;
  end;

  // determine the root of a library, according to the module names
  function sourceRoot(project: ICECommonProject): string;

implementation

{$R *.lfm}

uses
  ce_libman;

const
  notav: string = '< n/a >';

constructor TCELibManEditorWidget.Create(aOwner: TComponent);
begin
  inherited;
  AssignPng(btnMoveDown, 'arrow_down');
  AssignPng(btnMoveUp, 'arrow_up');
  AssignPng(btnAddLib, 'book_add');
  AssignPng(btnRemLib, 'book_delete');
  AssignPng(btnEditAlias, 'book_edit');
  AssignPng(btnSelFile, 'folder_brick');
  AssignPng(btnSelfoldOfFiles, 'bricks');
  AssignPng(btnSelRoot, 'folder_add');
  AssignPng(btnReg, 'book_link');
  AssignPng(btnDubFetch, 'dub_small');
  AssignPng(btnSelProj, 'script_bricks');
  AssignPng(btnOpenProj, 'book_open');
end;

procedure TCELibManEditorWidget.updateButtonsState;
begin
  btnReg.Enabled := (fProj <> nil) and (fProj.binaryKind = staticlib) and
    fProj.Filename.fileExists;
  btnOpenProj.Enabled := List.Selected.isNotNil and
    List.Selected.SubItems[2].fileExists;
end;

procedure TCELibManEditorWidget.projNew(aProject: ICECommonProject);
begin
  fProj := aProject;
end;

procedure TCELibManEditorWidget.projChanged(aProject: ICECommonProject);
begin
  if fProj = nil then exit;
  if fProj <> aProject then
    exit;
  //
  updateButtonsState;
end;

procedure TCELibManEditorWidget.projClosing(aProject: ICECommonProject);
begin
  if  fProj <> aProject then
    exit;
  fProj := nil;
  updateButtonsState;
end;

procedure TCELibManEditorWidget.projFocused(aProject: ICECommonProject);
begin
  fProj := aProject;
  updateButtonsState;
end;

procedure TCELibManEditorWidget.projCompiling(aProject: ICECommonProject);
begin
end;

procedure TCELibManEditorWidget.projCompiled(aProject: ICECommonProject; success: boolean);
begin
end;

procedure TCELibManEditorWidget.ListEdited(Sender: TObject; Item: TListItem; var AValue: string);
begin
  gridToData;
end;

procedure TCELibManEditorWidget.ListSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  updateButtonsState;
end;

procedure TCELibManEditorWidget.btnAddLibClick(Sender: TObject);
var
  itm: TListItem;
begin
  itm := List.Items.Add;
  itm.Caption := notav;
  itm.SubItems.Add(notav);
  itm.SubItems.Add(notav);
  itm.SubItems.Add(notav);
  SetFocus;
  itm.Selected := True;
end;

constructor TDubPackageQueryForm.Create(TheOwner: TComponent);
var
  bok: TBitBtn;
  bno: TBitBtn;
  bww: TBitBtn;
begin
  inherited;

  width  := 400;
  height := 36;
  BorderStyle:= bsToolWindow;
  caption := 'Select or type the DUB package name';
  Position:= poMainFormCenter;

  cbb := TComboBox.Create(self);
  cbb.Parent := self;
  cbb.AutoComplete := true;
  cbb.Align := alClient;
  cbb.BorderSpacing.Around := 2;
  cbb.Sorted:= true;

  bww := TBitBtn.Create(self);
  bww.Parent := self;
  bww.Align := alRight;
  bww.Width:= 28;
  bww.BorderSpacing.Around := 2;
  bww.ShowHint := true;
  bww.Hint := 'get the package list';
  bww.OnClick:= @getList;
  AssignPng(bww, 'arrow_update');

  bok := TBitBtn.Create(self);
  bok.Parent := self;
  bok.ModalResult:= mrOk;
  bok.Align := alRight;
  bok.Width := 28;
  bok.BorderSpacing.Around := 2;
  bok.Hint := 'try to fetch, compile and auto-register';
  bok.ShowHint := true;
  AssignPng(bok, 'accept');

  bno := TBitBtn.Create(self);
  bno.Parent := self;
  bno.ModalResult:= mrCancel;
  bno.Align := alRight;
  bno.Width:= 28;
  bno.BorderSpacing.Around := 2;
  bno.Hint := 'cancel and do nothing';
  bno.ShowHint := true;
  AssignPng(bno, 'cancel');
end;

procedure TDubPackageQueryForm.getList(sender: TObject);
var
  pge: string;
  cli: TFPHTTPClient;
begin
  cli := TFPHTTPClient.Create(self);
  pge := cli.Get('http://code.dlang.org/');
  // note, also works with regex \"packages\/[a-zA-Z0-9_-]+\"
  with TStringRange.create(pge) do while not empty do
  begin
    if popUntil('"')^.startsWith('"packages/') then
    begin
      popUntil('/')^.popFront;
      cbb.Items.Add(takeUntil('"').yield);
      popUntil('"')^.popFront;
    end
    else popFront;
  end;
end;

function TDubPackageQueryForm.getText: string;
begin
  result := cbb.Text;
end;

class function TDubPackageQueryForm.showAndWait(out value: string): TModalResult;
var
  frm: TDubPackageQueryForm;
begin
  frm := TDubPackageQueryForm.Create(nil);
  result := frm.ShowModal;
  if result = mrOk then
    value := frm.text
  else
    value := '';
  frm.Free;
end;

procedure TCELibManEditorWidget.btnDubFetchClick(Sender: TObject);
var
  dub: TProcess;
  nme: string = '';
  msg: string;
  pth: string;
  str: TStringList;
  itf: ICEMessagesDisplay;
  err: integer;
  idx: integer;
  prj: TCEDubProject;
  cdy: string;
  upd: boolean = false;
begin
  if TDubPackageQueryForm.showAndWait(nme) <> mrOk then
    exit;
  if List.Items.FindCaption(0, nme, false, false, false).isNotNil then
  begin
    dlgOkInfo(format('a library item with the alias "%s" already exists, delete it before trying again.',
      [nme]));
    exit;
  end;
  {$IFDEF WINDOWS}
  pth := GetEnvironmentVariable('APPDATA') + '\dub\packages\' + nme + '-master';
  {$ELSE}
  pth := GetEnvironmentVariable('HOME') + '/.dub/packages/' + nme + '-master';
  {$ENDIF}
  itf := getMessageDisplay;
  if pth.dirExists and not DeleteDirectory(pth, false) then
  begin
    upd := true;
    itf.message('information, the dub package is already fetched and will be upgraded', nil, amcMisc, amkInf);
  end;

  // fetch / updgrade
  dub := TProcess.Create(nil);
  try
    dub.Executable:= 'dub';
    dub.Options:= [poUsePipes, poStderrToOutPut];
    if not upd then
    begin
      dub.Parameters.Add('fetch');
      dub.Parameters.Add(nme);
      // fetch project, version handling, pth is hard to set because of semVer suffix.
      // needed: a folder monitor to detect the one created by dub.
      dub.Parameters.Add('--version=~master');
    end else
    begin
      dub.CurrentDirectory := pth;
      dub.Parameters.Add('upgrade');
    end;
    dub.Execute;
    while dub.Running do sleep(10);
    err := dub.ExitStatus;
    str := TStringList.Create;
    try
      processOutputToStrings(dub, str);
      for msg in str do
        itf.message(msg, nil, amcMisc, amkAuto);
    finally
      str.Free;
    end;
  finally
    dub.Free;
  end;
  if err <> 0 then
  begin
    itf.message('error, failed to fetch or upgrade the repository', nil, amcMisc, amkErr);
    exit;
  end;

  // build
  dub := TProcess.Create(nil);
  try
    dub.Executable:= 'dub';
    dub.Options:= [poUsePipes, poStderrToOutPut];
    dub.Parameters.Add('build');
    dub.Parameters.Add('--build=release');
    dub.CurrentDirectory:= pth;
    dub.Execute;
    while dub.Running do sleep(10);
    err := dub.ExitStatus;
    str := TStringList.Create;
    try
      processOutputToStrings(dub, str);
      for msg in str do
        itf.message(msg, nil, amcMisc, amkAuto);
    finally
      str.Free;
    end;
  finally
    dub.Free;
  end;
  if err <> 0 then
  begin
    itf.message('error, failed to compile the package to register', nil, amcMisc, amkErr);
    exit;
  end;

  // project used to get the infos
  EntitiesConnector.beginUpdate;
  prj := TCEDubProject.create(nil);
  try
    if FileExists(pth + DirectorySeparator + 'dub.json') then
      prj.loadFromFile(pth + DirectorySeparator + 'dub.json')
    else if FileExists(pth + DirectorySeparator + 'package.json') then
      prj.loadFromFile(pth + DirectorySeparator + 'package.json');
    if prj.filename.isNotEmpty and (prj.binaryKind = staticlib) then
    begin
      str := TStringList.Create;
      try
        for idx := 0 to prj.sourcesCount-1 do
          str.Add(prj.sourceAbsolute(idx));
        with List.Items.Add do
        begin
          Caption := nme;
          SubItems.Add(prj.outputFilename);
          cdy := sourceRoot(prj as ICECommonProject);
          SubItems.Add(cdy);
          SubItems.Add(prj.filename);
          Selected:=true;
        end;
      finally
        str.Free;
      end;
    end else
      itf.message('warning, the package json description can not be found or the target is not a static library',
        nil, amcMisc, amkWarn);
  finally
    prj.Free;
    EntitiesConnector.endUpdate;
    gridToData;
  end;
end;

procedure TCELibManEditorWidget.btnEditAliasClick(Sender: TObject);
var
  al: string;
begin
  if List.Selected.isNil then
    exit;
  al := List.Selected.Caption;
  if inputQuery('library alias', '', al) then
    List.Selected.Caption := al;
  gridToData;
end;

procedure TCELibManEditorWidget.btnOpenProjClick(Sender: TObject);
var
  fname: string;
begin
  if List.Selected.isNil then exit;
  fname := List.Selected.SubItems[2];
  if not fname.fileExists then exit;
  //
  if isValidNativeProject(fname) then
  begin
    if assigned(fProj) then
    begin
      if fProj.modified and (dlgFileChangeClose(fProj.filename) = mrCancel) then
        exit;
      fProj.getProject.Free;
    end;
    TCENativeProject.create(nil);
    fProj.loadFromFile(fname);
  end
  else if isValidDubProject(fname) then
  begin
    if assigned(fProj) then
    begin
      if fProj.modified and (dlgFileChangeClose(fProj.filename) = mrCancel) then
        exit;
      fProj.getProject.Free;
    end;
    TCEDubProject.create(nil);
    fProj.loadFromFile(fname);
  end
  else dlgOkInfo('the project file for this library seems to be invalid');
end;

procedure TCELibManEditorWidget.btnRegClick(Sender: TObject);
var
  str: TStringList;
  fname: string;
  root: string;
  lalias: string;
begin
  if fProj = nil then exit;
  //
  fname := fProj.filename;
  lalias := ExtractFileNameOnly(fname);
  if List.Items.FindCaption(0, lalias, false, false, false) <> nil then
  begin
    dlgOkInfo(format('a library item with the alias "%s" already exists, delete it before trying again.',
      [lalias]));
    exit;
  end;
  //
  str := TStringList.Create;
  try
    root := sourceRoot(fProj);
    if root.isEmpty then
    begin
      dlgOkInfo('the static library can not be registered because its source files have no common folder');
      exit;
    end;
    //
    fname := fProj.outputFilename;
    with List.Items.Add do
    begin
      Caption := ExtractFileNameOnly(fname);
      if fname.extractFileExt <> libExt then
        SubItems.add(fname + libExt)
      else
        SubItems.add(fname);
      SubItems.add(root);
      SubItems.add(fProj.filename);
      if not SubItems[0].fileExists then
        dlgOkInfo('the library file does not exist, maybe the project not been already compiled ?');
      Selected:= true;
    end;
    SetFocus;
    gridToData;
  finally
    str.free;
  end;
end;

procedure TCELibManEditorWidget.btnRemLibClick(Sender: TObject);
begin
  if List.Selected.isNil then
    exit;
  List.Items.Delete(List.Selected.Index);
  gridToData;
end;

procedure TCELibManEditorWidget.btnSelProjClick(Sender: TObject);
var
  ini: string = '';
begin
  if List.Selected.isNil then
    exit;
  if List.Selected.SubItems.Count > 2 then
    ini := List.Selected.SubItems[2]
  else while List.Selected.SubItems.Count < 3 do
    List.Selected.SubItems.Add(ini);
  with TOpenDialog.Create(nil) do try
    FileName := ini;
    if Execute then
      List.Selected.SubItems[2] := FileName;
  finally
    free;
  end;
  gridToData;
end;

procedure TCELibManEditorWidget.btnSelFileClick(Sender: TObject);
var
  ini: string = '';
begin
  if List.Selected.isNil then
    exit;
  if List.Selected.SubItems.Count > 0 then
    ini := List.Selected.SubItems[0]
  else
    List.Selected.SubItems.Add(ini);
  with TOpenDialog.Create(nil) do
    try
      filename := ini;
      if Execute then
      begin
        if not filename.fileExists then
          List.Selected.SubItems[0] := filename.extractFilePath
        else
        begin
          List.Selected.SubItems[0] := filename;
          if (List.Selected.Caption.isEmpty) or (List.Selected.Caption = notav) then
            List.Selected.Caption := ChangeFileExt(filename.extractFileName, '');
        end;
      end;
    finally
      Free;
    end;
  gridToData;
end;

procedure TCELibManEditorWidget.btnSelfoldOfFilesClick(Sender: TObject);
var
  dir, outdir: string;
begin
  if List.Selected.isNil then
    exit;
  if List.Selected.SubItems.Count > 0 then
    dir := List.Selected.SubItems[0]
  else
  begin
    dir := '';
    List.Selected.SubItems.Add(dir);
  end;
  if selectDirectory('folder of static libraries', dir, outdir, True, 0) then
    List.Selected.SubItems[0] := outdir;
  gridToData;
end;

procedure TCELibManEditorWidget.btnSelRootClick(Sender: TObject);
var
  dir, outdir: string;
begin
  if List.Selected.isNil then
    exit;
  if List.Selected.SubItems.Count > 1 then
    dir := List.Selected.SubItems[1]
  else
  begin
    dir := '';
    while List.Selected.SubItems.Count < 2 do
      List.Selected.SubItems.Add(dir);
  end;
  if selectDirectory('sources root', dir, outdir, True, 0) then
    List.Selected.SubItems[1] := outdir;
  gridToData;
end;

procedure TCELibManEditorWidget.btnMoveUpClick(Sender: TObject);
begin
  if list.Selected.isNil then
    exit;
  if list.Selected.Index = 0 then
    exit;
  //
  list.Items.Exchange(list.Selected.Index, list.Selected.Index - 1);
  gridToData;
end;

procedure TCELibManEditorWidget.btnMoveDownClick(Sender: TObject);
begin
  if list.Selected.isNil then
    exit;
  if list.Selected.Index = list.Items.Count - 1 then
    exit;
  //
  list.Items.Exchange(list.Selected.Index, list.Selected.Index + 1);
  gridToData;
end;

procedure TCELibManEditorWidget.DoShow;
begin
  inherited;
  dataToGrid;
end;

procedure TCELibManEditorWidget.dataToGrid;
var
  itm: TLibraryItem;
  row: TListItem;
  i: Integer;
begin
  if LibMan.isNil then
    exit;
  List.BeginUpdate;
  List.Clear;
  for i := 0 to LibMan.libraries.Count - 1 do
  begin
    itm := TLibraryItem(LibMan.libraries.Items[i]);
    row := List.Items.Add;
    row.Caption := itm.libAlias;
    row.SubItems.Add(itm.libFile);
    row.SubItems.Add(itm.libSourcePath);
    row.SubItems.Add(itm.projectFile);
  end;
  List.EndUpdate;
end;

procedure TCELibManEditorWidget.gridToData;
var
  itm: TLibraryItem;
  row: TListItem;
begin
  if LibMan.isNil then
    exit;
  LibMan.libraries.BeginUpdate;
  LibMan.libraries.Clear;
  for row in List.Items do
  begin
    itm := TLibraryItem(LibMan.libraries.Add);
    itm.libAlias := row.Caption;
    itm.libFile := row.SubItems[0];
    itm.libSourcePath := row.SubItems[1];
    itm.projectFile:= row.SubItems[2];
  end;
  LibMan.libraries.EndUpdate;
  LibMan.updateDCD;
end;

function sourceRoot(project: ICECommonProject): string;
var
  i, j: integer;
  name: string;
  fold: string;
  modn: TStringList;
  modf: TStringList;
  toks: TLexTokenList;
  base: string;
begin
  base := project.basePath;

  // 1 source, same folder
  if project.sourcesCount = 1 then
  begin
    name := project.sourceAbsolute(0);
    if name.extractFilePath = base then
      exit(base);
  end;

  modn := TStringList.Create;
  modf := TStringList.Create;
  toks := TLexTokenList.Create;
  try
    // get module name and store the parent.parent.parent... dir
    for i := 0 to project.sourcesCount-1 do
    begin
      fold := project.sourceAbsolute(i);
      modf.LoadFromFile(fold);
      lex(modf.Text, toks);
      name := getModuleName(toks);
      for j := 0 to WordCount(name, ['.'])-1 do
        fold := extractFileDir(fold);
      modn.Add(fold);
      toks.Clear;
    end;
    result := modn[0];
    // no error possible if 1 module
    if project.sourcesCount > 1 then
    begin
      for i := 1 to modn.Count-1 do
      begin
        // expect same folder
        if modn[i] = modn[i-1] then
          continue;
        // if not use common directory.
        modf.Clear;
        for j := 0 to project.sourcesCount-1 do
          modf.Add(project.sourceAbsolute(j));
        result := commonFolder(modf);
        result := result.extractFileDir;
        break;
      end;
    end;
  finally
    modf.Free;
    modn.Free;
    toks.Free;
  end;
end;

end.
