{
    Copyright (C) 2026 VCC
    creation date: 2026
    initial release date: 05 Nov 2026

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


unit ExportedFunctions;

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils, MemStatPlugins;


procedure LoadLstFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
procedure LoadHexFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
function GetMemEntryCount: DWord; cdecl;
procedure GetMemEntry(ACallback: TGetMemEntryCallback; AEntryIndex: DWord); cdecl;  //AEntryIndex can go from 0 to GetMemEntryCount - 1
procedure GetStatistics(ACallback: TGetPluginStatisticsCallback); cdecl;


implementation


var
  FLstContent: TStringList;
  HeapFound: Boolean;
  HeapAddr: DWord;
  HeapSize: DWord;


procedure LoadLstFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
var
  FileName: string;
  i: Integer;
  s: string;
  s1, s2, s3, s4: string;

  HEAP_SIZE_HiWord: LongInt;
  HEAP_SIZE_LoWord: LongInt;
  HEAP_START_HiWord: LongInt;
  HEAP_START_LoWord: LongInt;
begin
  SetLength(FileName, AFileNameLen);
  Move(AFileName^, FileName[1], AFileNameLen);
  FLstContent.LoadFromFile(FileName);

  HEAP_SIZE_HiWord := -1;
  HEAP_SIZE_LoWord := -1;
  HEAP_START_HiWord := -1;
  HEAP_START_LoWord := -1;

  for i := 0 to FLstContent.Count - 1 do
  begin
    s := FLstContent.Strings[i];

    if (HEAP_SIZE_HiWord = -1) and (HEAP_SIZE_LoWord = -1) then
      if (Pos(';__Lib_MemManager.mpas, ', s) > 0) and (Pos('MM_FreeMemTable[0].Size    := HEAP_SIZE;', s) > 0) then
      begin
        try  //using try..except in case the stringlist does not have the next expected lines
          s1 := FLstContent.Strings[i + 1];
          s2 := FLstContent.Strings[i + 2];
          s3 := FLstContent.Strings[i + 3];
          s4 := FLstContent.Strings[i + 4];
          //MessageBox(0, PChar('SIZE  s1=' + s1 + #13#10 + 's2=' + s2 + #13#10 + 's3=' + s3 + #13#10 + 's4=' + s4), 'MemStat', MB_ICONINFORMATION);

          if (Pos('LUI	R2, ', s1) > 0) and
             (Pos('ORI	R2, R2, ', s2) > 0) and
             (Pos('SW	R2, Offset(__Lib_MemManager_MM_FreeMemTable+4)(GP)', s3) > 0) then
          begin
            HEAP_SIZE_HiWord := StrToIntDef(Copy(s1, Pos('R2, ', s1) + Length('R2, '), MaxInt), -1);
            HEAP_SIZE_LoWord := StrToIntDef(Copy(s2, Pos('R2, R2, ', s2) + Length('R2, R2, '), MaxInt), -1);
          end
          else
            if (Pos('ORI	R2, R0, ', s1) > 0) and
               (Pos('SW	R2, Offset(__Lib_MemManager_MM_FreeMemTable+4)(GP)', s2) > 0) then
            begin
              HEAP_SIZE_HiWord := 0;
              HEAP_SIZE_LoWord := StrToIntDef(Copy(s1, Pos('R2, R0, ', s1) + Length('R2, R0, '), MaxInt), -1);
            end
            else
              if (Pos('LUI	R2, ', s1) > 0) and
                 (Pos('ORI	R2, R2, ', s2) > 0) and
                 (Pos('LUI	R30, ', s3) > 0) and
                 (Pos('SW	R2', s4) > 0) then
              begin
                HEAP_SIZE_HiWord := StrToIntDef(Copy(s1, Pos('R2, ', s1) + Length('R2, '), MaxInt), -1);
                HEAP_SIZE_LoWord := StrToIntDef(Copy(s2, Pos('R2, R2, ', s2) + Length('R2, R2, '), MaxInt), -1);
              end;
        except
        end;

        if (HEAP_START_HiWord > -1) and (HEAP_START_LoWord > -1) then
          if (HEAP_SIZE_HiWord > -1) and (HEAP_SIZE_LoWord > -1) then
          begin
            HeapFound := True;
            Break;
          end;
      end;  //HEAP_SIZE

    if (HEAP_START_HiWord = -1) and (HEAP_START_LoWord = -1) then
      if (Pos(';__Lib_MemManager.mpas, ', s) > 0) and (Pos('MM_FreeMemTable[0].Pointer := TBytePtr(HEAP_START);', s) > 0) then
      begin
        try  //using try..except in case the stringlist does not have the next expected lines
          s1 := FLstContent.Strings[i + 1];
          s2 := FLstContent.Strings[i + 2];
          s3 := FLstContent.Strings[i + 3];
          s4 := FLstContent.Strings[i + 4];
          //MessageBox(0, PChar('START  s1=' + s1 + #13#10 + 's2=' + s2 + #13#10 + 's3=' + s3 + #13#10 + 's4=' + s4), 'MemStat', MB_ICONINFORMATION);

          if (Pos('LUI	R2, ', s1) > 0) and
             (Pos('ORI	R2, R2, ', s2) > 0) and
             (Pos('SW	R2, Offset(__Lib_MemManager_MM_FreeMemTable+0)(GP)', s3) > 0) then
          begin
            HEAP_START_HiWord := StrToIntDef(Copy(s1, Pos('R2, ', s1) + Length('R2, '), MaxInt), -1);
            HEAP_START_LoWord := StrToIntDef(Copy(s2, Pos('R2, R2, ', s2) + Length('R2, R2, '), MaxInt), -1);
          end
          else
            if (Pos('ORI	R2, R0, ', s1) > 0) and
               (Pos('SW	R2, Offset(__Lib_MemManager_MM_FreeMemTable+0)(GP)', s2) > 0) then
            begin
              HEAP_START_HiWord := 0;
              HEAP_START_LoWord := StrToIntDef(Copy(s1, Pos('R2, R0, ', s1) + Length('R2, R0, '), MaxInt), -1);
            end
            else
              if (Pos('ORI	R2, R0, ', s1) > 0) and
                 (Pos('LUI	R30, ', s2) > 0) and
                 (Pos('SW	R2', s3) > 0) then
              begin
                HEAP_START_HiWord := 0;
                HEAP_START_LoWord := StrToIntDef(Copy(s1, Pos('R2, R0, ', s1) + Length('R2, R0, '), MaxInt), -1);
              end ;
        except
        end;

        if (HEAP_START_HiWord > -1) and (HEAP_START_LoWord > -1) then
          if (HEAP_SIZE_HiWord > -1) and (HEAP_SIZE_LoWord > -1) then
          begin
            HeapFound := True;
            Break;
          end;
      end;  //HEAP_START
  end; //for

  if HeapFound then
  begin
    HeapAddr := HEAP_START_HiWord shl 16 + HEAP_START_LoWord;
    HeapSize := HEAP_SIZE_HiWord shl 16 + HEAP_SIZE_LoWord;
  end;
end;


procedure LoadHexFile(AFileName: Pointer; AFileNameLen: DWord); cdecl;
begin

end;


function GetMemEntryCount: DWord; cdecl;
begin
  if HeapFound then
    Result := 1     //Expecting a single heap (for now)
  else
    Result := 0;
end;


procedure GetMemEntry(ACallback: TGetMemEntryCallback; AEntryIndex: DWord); cdecl;  //AEntryIndex can go from 0 to GetMemEntryCount - 1
var
  Entry: TMemEntryAPI;
  TempEntryName: string;
begin
  if ACallback = nil then
    Exit;

  if AEntryIndex <> 0 then  //Expecting a single heap (for now)
    Exit;

  if not HeapFound then
    Exit;

  TempEntryName := 'Heap';
  Entry.Address := HeapAddr;
  Entry.Size := HeapSize;
  Entry.EntryName := @TempEntryName[1];
  Entry.EntryNameLen := Length(TempEntryName);
  Entry.Index := AEntryIndex;

  ACallback(Entry);
  TempEntryName := '';
end;


procedure GetStatistics(ACallback: TGetPluginStatisticsCallback); cdecl;
var
  TempStatistics: string;
begin
  if ACallback = nil then
    Exit;

  TempStatistics := 'Hello from MemStatHeap plugin.';
  ACallback(@TempStatistics[1], Length(TempStatistics));
  TempStatistics := '';
end;


initialization
  FLstContent := TStringList.Create;
  HeapFound := False;

finalization
  FreeAndNil(FLstContent);

end.

