unit Unit_AIModel.Probing;

interface

uses
  System.SysUtils,
  System.StrUtils ,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.JSON,
  Unit_AIModel.TAIModelConfig,
  Unit_AIModel.Helper,
  Unit_AIModel.GetInternalToken;

function ProbeModelAccess(const ModelName: string;
  const aAIModelConfig: TAIModelConfig; out Info: string;
  const AuthHeaderOverride: string = ''): Boolean;

function ProbeAllCompanyInternalModels(const aAIModelConfig: TAIModelConfig;
  out AccessibleModels, InaccessibleModels: TArray<string>; out Info: string;
  const AuthHeaderOverride: string = ''): Boolean;


function FetchModelsList(const AuthHeader: string; const C: TAIModelConfig;
  out Models: TArray<string>; out Info: string; const EnableDebug: Boolean): Boolean;

implementation




function FetchModelsList(const AuthHeader: string; const C: TAIModelConfig;
  out Models: TArray<string>; out Info: string; const EnableDebug: Boolean): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  URL, S: string;
  Root: TJSONValue;
  DataArr: TJSONValue;
  i: Integer;
  Item: TJSONValue;
  Obj: TJSONObject;
begin
  Result := False;
  Info := '';
  Models := nil;

  if (C.BaseURL = '') or (C.ModelsPath = '') then
  begin
    Info := 'Missing BaseURL/ModelsPath in config.';
    Exit(False);
  end;

  URL := JoinUrl(C.BaseURL, C.ModelsPath);

  Http := THTTPClient.Create;
  try
    Resp := Http.Get(URL, nil, [
      TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)
    ]);

    if (Resp = nil) or (Resp.StatusCode <> 200) then
    begin
      Info := Format('HTTP %d %s', [Resp.StatusCode, Resp.StatusText]);
      Exit(False);
    end;

    S := Resp.ContentAsString(TEncoding.UTF8);
    Root := TJSONObject.ParseJSONValue(S);
    try
      if (Root = nil) or not (Root is TJSONObject) then
      begin
        Info := 'Invalid JSON root in models response.';
        Exit(False);
      end;

      DataArr := (Root as TJSONObject).GetValue('data');
      if (DataArr = nil) or not (DataArr is TJSONArray) then
      begin
        Info := 'Missing or invalid "data" array in models response.';
        Exit(False);
      end;

      SetLength(Models, TJSONArray(DataArr).Count);
      for i := 0 to TJSONArray(DataArr).Count - 1 do
      begin
        Item := TJSONArray(DataArr).Items[i];
        if (Item is TJSONObject) then
        begin
          Obj := TJSONObject(Item);
          if Obj.GetValue('id') <> nil then
            Models[i] := Obj.GetValue('id').Value
          else
            Models[i] := '';
        end
        else
          Models[i] := '';
      end;

      Info := 'Models listed successfully: ' + Length(Models).ToString;
      Result := True;
    finally
      Root.Free;
    end;
  finally
    Http.Free;
  end;
end;




function BuildAuthHeader(const AuthHeaderOverride: string): string;
var
  Token: string;
begin
  if AuthHeaderOverride <> '' then
    Exit(AuthHeaderOverride);

  Token := GetCompanyInternalToken; // falls back to INI/defaults on your gateway

  if Token = '' then
    Token := GetCompanyInternalToken; // alternative helper

  if Token <> '' then
    Result := 'Bearer ' + Token
  else
    Result := '';
end;

function CombineUrl(const Base, Path: string): string;
begin
  if Base.EndsWith('/') and Path.StartsWith('/') then
    Result := Base + Path.Substring(1)
  else if (not Base.EndsWith('/')) and (not Path.StartsWith('/')) then
    Result := Base + '/' + Path
  else
    Result := Base + Path;
end;

function PostChatCompletionPing(const AuthHeader, ModelName, BaseURL,
  ChatCompletionsPath: string; const TimeoutMS: Integer;
  out Info: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  URL, BodyStr, RespStr: string;
  BodyJson, Msgs: TJSONObject;
  ArrMsgs: TJSONArray;
  Headers: TArray<TNameValuePair>;
  StatusOK: Boolean;
  Strm: TStringStream;
begin
  Info := '';
  Result := False;

  if AuthHeader = '' then
  begin
    Info := 'Authorization header is empty; cannot probe model.';
    Exit(False);
  end;

  Http := THTTPClient.Create;
  try
    if TimeoutMS > 0 then
    begin
      Http.ConnectionTimeout := TimeoutMS;
      Http.ResponseTimeout := TimeoutMS;
    end;

    URL := CombineUrl(BaseURL, ChatCompletionsPath);

    Headers := [TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)];

    // Build minimal OpenAI-compatible body
    BodyJson := TJSONObject.Create;
    try
      BodyJson.AddPair('model', ModelName);

      ArrMsgs := TJSONArray.Create;
      Msgs := TJSONObject.Create;
      Msgs.AddPair('role', 'user');
      Msgs.AddPair('content', 'ping');
      ArrMsgs.AddElement(Msgs);
      BodyJson.AddPair('messages', ArrMsgs);

      if UseMaxCompletionTokens(ModelName) then // per helper [5]
        BodyJson.AddPair('max_completion_tokens', TJSONNumber.Create(1))
      else
        BodyJson.AddPair('max_tokens', TJSONNumber.Create(1));

      if not ModelRequiresDefaultTemperature(ModelName) then // per helper [5]
        BodyJson.AddPair('temperature', TJSONNumber.Create(0.0));

      BodyStr := BodyJson.ToJSON;
    finally
      BodyJson.Free; // frees ArrMsgs and Msgs as owned JSON
    end;

    Strm := TStringStream.Create(BodyStr, TEncoding.UTF8);
    try
      Resp := Http.Post(URL, Strm, nil, Headers);
    finally
      Strm.Free;
    end;

    StatusOK := (Resp.StatusCode >= 200) and (Resp.StatusCode < 300);
    RespStr := Resp.ContentAsString(TEncoding.UTF8);

    Info := 'POST ' + URL + sLineBreak + 'Model=' + ModelName + sLineBreak +
      'StatusCode=' + Resp.StatusCode.ToString + ' ' + Resp.StatusText +
      sLineBreak;

    if not StatusOK then
    begin
      Info := Info + 'Probe failed (non-2xx).';
      Exit(False);
    end;

    // Basic validation: response must contain choices
    Result := RespStr.Contains('"choices"');
    if Result then
      Info := Info + 'Probe OK (choices present).'
    else
      Info := Info + 'Probe incomplete (choices missing).';
  except
    on E: Exception do
    begin
      Info := 'Error probing model ' + ModelName + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

function ProbeModelAccess(const ModelName: string;
  const aAIModelConfig: TAIModelConfig; out Info: string;
  const AuthHeaderOverride: string = ''): Boolean;
var
  AuthHeader: string;
  ChatPath, BaseURL: string;
begin
  AuthHeader := BuildAuthHeader(AuthHeaderOverride);

  BaseURL := aAIModelConfig.BaseURL; // from config

  if aAIModelConfig.ChatCompletionsPath <> '' then
    ChatPath := aAIModelConfig.ChatCompletionsPath
  else
    ChatPath := '/chat/completions'; // default is OpenAI-compatible


    Result := PostChatCompletionPing(AuthHeader, ModelName, BaseURL, ChatPath,
    aAIModelConfig.TimeoutMS, Info);
end;

function FetchAllModels(const AuthHeader: string;
  const aAIModelConfig: TAIModelConfig; out Models: TArray<string>;
  out Info: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  URL, S: string;
  Root, DataArr, Item: TJSONValue;
  i: Integer;
  Headers: TArray<TNameValuePair>;
begin
  Info := '';
  Result := False;
  SetLength(Models, 0);

  if AuthHeader = '' then
  begin
    Info := 'Authorization header is empty; cannot list models.';
    Exit(False);
  end;

  Http := THTTPClient.Create;
  try
    if aAIModelConfig.TimeoutMS > 0 then
    begin
      Http.ConnectionTimeout := aAIModelConfig.TimeoutMS;
      Http.ResponseTimeout := aAIModelConfig.TimeoutMS;
    end;

    URL := CombineUrl(aAIModelConfig.BaseURL, aAIModelConfig.ModelsPath);
    // from config [6]

    Headers := [TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)];

    Resp := Http.Get(URL, nil, Headers);
    if (Resp.StatusCode < 200) or (Resp.StatusCode >= 300) then
    begin
      Info := 'GET ' + URL + sLineBreak + 'StatusCode=' +
        Resp.StatusCode.ToString + ' ' + Resp.StatusText;
      Exit(False);
    end;

    S := Resp.ContentAsString(TEncoding.UTF8);
    Root := TJSONObject.ParseJSONValue(S);
    try
      if (Root = nil) or not(Root is TJSONObject) then
      begin
        Info := 'Invalid JSON root in models response.';
        Exit(False);
      end;

      DataArr := (Root as TJSONObject).GetValue('data');
      if (DataArr = nil) or not(DataArr is TJSONArray) then
      begin
        Info := 'Missing or invalid "data" array in models response.';
        Exit(False);
      end;

      SetLength(Models, TJSONArray(DataArr).Count);
      for i := 0 to TJSONArray(DataArr).Count - 1 do
      begin
        Item := TJSONArray(DataArr).Items[i];
        if (Item is TJSONObject) and (TJSONObject(Item).GetValue('id') <> nil)
        then
          Models[i] := TJSONObject(Item).GetValue('id').Value
        else
          Models[i] := '';
      end;

      Info := 'Models listed successfully: ' + Length(Models).ToString;
      Result := True;
    finally
      Root.Free;
    end;
  finally
    Http.Free;
  end;
end;

function ProbeAllCompanyInternalModels(const aAIModelConfig: TAIModelConfig;
  out AccessibleModels, InaccessibleModels: TArray<string>; out Info: string;
  const AuthHeaderOverride: string = ''): Boolean;
var
  AuthHeader: string;
  Models: TArray<string>;
  M: string;
  Ok: Boolean;
  ListInfo, ProbeInfo: string;
  AOK, NOK: TArray<string>;
begin
  Info := '';
  Result := False;
  SetLength(AccessibleModels, 0);
  SetLength(InaccessibleModels, 0);

  AuthHeader := BuildAuthHeader(AuthHeaderOverride);

  if not FetchAllModels(AuthHeader, aAIModelConfig, Models, ListInfo) then
  begin
    Info := 'Failed to fetch models from gateway.' + sLineBreak + ListInfo;
    Exit(False);
  end;

  for M in Models do
  begin
    if M = '' then
      Continue;

    Ok := ProbeModelAccess(M, aAIModelConfig, ProbeInfo, AuthHeader);
    if Ok then
    begin
      AOK := AccessibleModels;
      SetLength(AOK, Length(AOK) + 1);
      AOK[High(AOK)] := M;
      AccessibleModels := AOK;
    end
    else
    begin
      NOK := InaccessibleModels;
      SetLength(NOK, Length(NOK) + 1);
      NOK[High(NOK)] := M;
      InaccessibleModels := NOK;
    end;

    Info := Info + '[' + M + '] ' + (ifThen(Ok, 'OK', 'FAIL')) + sLineBreak +
      ProbeInfo + sLineBreak;
  end;

  Result := True;
end;

end.
