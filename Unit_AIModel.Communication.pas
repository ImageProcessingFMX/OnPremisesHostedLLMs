unit Unit_AIModel.Communication;

interface


///
///   very basic test  of access to AI model
///   update 20.04.2026  ProbeEndpoint with more tokens
///


uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.NetEncoding,
  System.JSON,   math,
  ///
  ///     HTTP Based
  ///
  Unit_AIModel.TAIModelConfig,
  Unit_AIModel.Helper;



const
  // Use lowercase /v1 for OpenAI-compatible endpoints

  /// OpenAI-compatible endpoint for chat-based AI interactions (GPT-style conversations)
  /// POST request with messages array, returns AI-generated responses
  CHAT_COMPLETIONS = '/chat/completions';

  /// OpenAI-compatible endpoint for text completion (legacy/simple prompt-response)
  /// POST request with prompt string, returns generated text continuation
  COMPLETIONS = '/completions';

  /// OpenAI-compatible endpoint for generating vector embeddings from text
  /// POST request with text input, returns numerical vector representation
  EMBEDDINGS = '/embeddings';

  /// OpenAI-compatible endpoint to list available AI models
  /// GET request, returns array of model names and capabilities
  MODELS = '/models';

  /// Company-specific authentication endpoint to retrieve bearer token
  /// GET request, returns JWT token required for authenticating API calls
  AUTH_TOKEN_ENDPOINT = '/auth/token';


  function EncodeBasic(const User, Pass: string): string;

  procedure DumpHeaders(const Headers: TNetHeaders);


  function GetPermanentTokenViaBasic(const UsedURL : String; const User, Pass: string;
  EnableDebug: Boolean): string;


  function PostChatCompletions( const AuthHeader: string;
  const  Question: string; EnableDebug: Boolean; aAIModelConfig : TAIModelConfig ): string;


  function FetchModels(const UsedURL : String; const AuthHeader: string; EnableDebug: Boolean): Boolean;


  function ProbeEndpoints(const UsedURL : String;  const AuthHeader: string; EnableDebug: Boolean)
  : Boolean;    overload;


  function ProbeEndpoints(const AuthHeader: string; EnableDebug: Boolean;
  const BaseURL, ChatPath: string; const ModelName: string;
  const TimeoutMS: Integer): Boolean;   overload;


implementation



function EncodeBasic(const User, Pass: string): string;
begin
  Result := TNetEncoding.Base64.Encode(User + ':' + Pass);
end;

procedure DumpHeaders(const Headers: TNetHeaders);
var
  I: Integer;
begin
  for I := 0 to High(Headers) do
    Writeln(' ' + Headers[I].Name + ': ' + Headers[I].Value);
end;

function PrettyJSON(const S: string): string;
var
  I, Indent: Integer;
  InString, Escape: Boolean;
  c: Char;
begin
  Result := '';
  Indent := 0;
  InString := False;
  Escape := False;
  for I := 1 to Length(S) do
  begin
    c := S[I];
    if InString then
    begin
      Result := Result + c;
      if Escape then
        Escape := False
      else if c = '' then
        Escape := True
      else if c = '"' then
        InString := False;
    end
    else
    begin
      case c of
        ' ', #9, #10, #13:
          ; // skip whitespace outside strings
        '{', '[':
          begin
            Result := Result + c + sLineBreak;
            Inc(Indent);
            Result := Result + StringOfChar(' ', Indent * 2);
          end;
        '}', ']':
          begin
            Result := Result + sLineBreak;
            Dec(Indent);
            Result := Result + StringOfChar(' ', Indent * 2) + c;
          end;
        ',':
          begin
            Result := Result + c + sLineBreak + StringOfChar(' ', Indent * 2);
          end;
        ':':
          Result := Result + ': ';
        '"':
          begin
            InString := True;
            Result := Result + c;
          end;
      else
        Result := Result + c;
      end;
    end;
  end;
end;

function GetPermanentTokenViaBasic( const  UsedURL : String;   const User, Pass: string;
  EnableDebug: Boolean): string;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  URL: string;
  Headers: TNetHeaders;
  RawResp: string;
begin
  Result := '';
  Client := THTTPClient.Create;
  try
    URL := UsedURL + AUTH_TOKEN_ENDPOINT; // Important: not under /v1
    Headers := [TNameValuePair.Create('Authorization',
      'Basic ' + EncodeBasic(User, Pass)), TNameValuePair.Create('Content-Type',
      'application/json'), TNameValuePair.Create('Accept', 'application/json')];

    if EnableDebug then
    begin
      Writeln('--- GET ' + URL + ' ---');
      Writeln('Headers:');
      DumpHeaders(Headers);
      Writeln;
    end;

    Resp := Client.Get(URL, nil, Headers);
    RawResp := Resp.ContentAsString(TEncoding.UTF8);

    if EnableDebug then
    begin
      Writeln('--- Response ---');
      Writeln(Format('Status: %d %s', [Resp.StatusCode, Resp.StatusText]));
      Writeln('Headers:');
      DumpHeaders(Resp.Headers);
      Writeln('Body:');
      if RawResp <> '' then
        Writeln(RawResp)
      else
        Writeln('(empty)');
      Writeln('--- End Response ---');
      Writeln;
    end;

    if Resp.StatusCode = 200 then
      Result := RawResp
    else
      Writeln(Format('Token request failed: %d %s', [Resp.StatusCode,
        Resp.StatusText]));
  finally
    Client.Free;
  end;
end;



  function PostChatCompletions(   const AuthHeader: string;
  const  Question: string; EnableDebug: Boolean; aAIModelConfig : TAIModelConfig ): string;
var
  Client: THTTPClient;
  ReqJson: TJSONObject;
  Messages: TJSONArray;
  MsgUser: TJSONObject;
  Resp: IHTTPResponse;
  ReqStream: TStringStream;
  URL: string;
  Headers: TNetHeaders;
  RawResp: string;
  RespJson: TJSONObject;
  Choices: TJSONArray;
  ChoiceObj, MsgObj: TJSONObject;
  Content: string;
begin
  Result := '';
  Client := THTTPClient.Create;
  try
    // Build OpenAI-style body
    ReqJson := TJSONObject.Create;
    try
      Messages := TJSONArray.Create;
      MsgUser := TJSONObject.Create;
      MsgUser.AddPair('role', 'user');
      MsgUser.AddPair('content', Question);
      Messages.AddElement(MsgUser);

      ReqJson.AddPair('model', aAIModelConfig.Model);
      ReqJson.AddPair('messages', Messages);


      if UseMaxCompletionTokens(aAIModelConfig.Model) then
        ReqJson.AddPair('max_completion_tokens', TJSONNumber.Create(aAIModelConfig.MaxTokens))
      else
        ReqJson.AddPair('max_tokens', TJSONNumber.Create(aAIModelConfig.MaxTokens));




      // Temperature: omit for Azure-backed (or set to 1.0 if you prefer)
      if not ModelRequiresDefaultTemperature(aAIModelConfig.Model) then
        ReqJson.AddPair('temperature', TJSONNumber.Create(0.7));
      // else: do not add temperature (or add 1.0 if absolutely needed)

      URL := aAIModelConfig.BaseURL + CHAT_COMPLETIONS;
      Headers := [TNameValuePair.Create('Content-Type', 'application/json'),
        TNameValuePair.Create('Accept', 'application/json'),
        TNameValuePair.Create('Authorization', AuthHeader)];

      if EnableDebug then
      begin
        Writeln('--- POST ' + URL + ' ---');
        Writeln('Headers:');
        DumpHeaders(Headers);
        Writeln('Request JSON:');
        Writeln(PrettyJSON(ReqJson.ToJSON));
        Writeln('--- End Request ---');
        Writeln;
      end;

      ReqStream := TStringStream.Create(ReqJson.ToJSON, TEncoding.UTF8);
      try
        ReqStream.Position := 0;
        Resp := Client.Post(URL, ReqStream, nil, Headers);
      finally
        ReqStream.Free;
      end;

      RawResp := Resp.ContentAsString(TEncoding.UTF8);

      if EnableDebug then
      begin
        Writeln('--- Response ---');
        Writeln(Format('Status: %d %s', [Resp.StatusCode, Resp.StatusText]));
        Writeln('Headers:');
        DumpHeaders(Resp.Headers);
        Writeln('Body:');
        if RawResp <> '' then
          Writeln(PrettyJSON(RawResp))
        else
          Writeln('(empty)');
        Writeln('--- End Response ---');
        Writeln;
      end;

      if Resp.StatusCode <> 200 then
      begin
        Result := Format('Request failed: %d %s',
          [Resp.StatusCode, Resp.StatusText]);
        Exit;
      end;

      // Parse response: choices[0].message.content
      RespJson := TJSONObject(TJSONObject.ParseJSONValue(RawResp));
      try
        if (RespJson <> nil) and RespJson.TryGetValue<TJSONArray>('choices',
          Choices) and (Choices.Count > 0) and (Choices.Items[0] is TJSONObject)
        then
        begin
          ChoiceObj := TJSONObject(Choices.Items[0]);
          if ChoiceObj.TryGetValue<TJSONObject>('message', MsgObj) and
            (MsgObj <> nil) and MsgObj.TryGetValue<string>('content', Content)
          then
            Result := Content
          else
            Result := '(No message.content found in response)';
        end
        else
          Result := '(Unexpected response shape)';
      finally
        RespJson.Free;
      end;
    finally
      ReqJson.Free;
    end;
  finally
    Client.Free;
  end;
end;

function FetchModels(const UsedURL : String ; const AuthHeader: string; EnableDebug: Boolean): Boolean;
var
  Client: THTTPClient;
  URL: string;
  Resp: IHTTPResponse;
  Headers: TNetHeaders;
  Raw: string;
begin
  Result := False;
  Client := THTTPClient.Create;
  try
    URL := UsedURL + MODELS;
    Headers := [TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)];
    if EnableDebug then
    begin
      Writeln('--- GET ' + URL + ' ---');
      Writeln('Headers:');
      DumpHeaders(Headers);
      Writeln;
    end;
    Resp := Client.Get(URL, nil, Headers);
    Raw := Resp.ContentAsString(TEncoding.UTF8);
    if EnableDebug then
    begin
      Writeln('--- Response ---');
      Writeln(Format('Status: %d %s', [Resp.StatusCode, Resp.StatusText]));
      Writeln('Headers:');
      DumpHeaders(Resp.Headers);
      Writeln('Body:');
      if Raw <> '' then
        Writeln(PrettyJSON(Raw))
      else
        Writeln('(empty)');
      Writeln('--- End Response ---');
      Writeln;
    end;
    Result := (Resp.StatusCode = 200);
    if not Result then
      Writeln('FetchModels: non-200 on ' + URL);
  finally
    Client.Free;
  end;
end;

function ProbeEndpoints(const UsedURL : String;    const AuthHeader: string; EnableDebug: Boolean)
  : Boolean;
var
  Client: THTTPClient;
  URL: string;
  Headers: TNetHeaders;
  Body: string;
  Resp: IHTTPResponse;
  Stream: TStringStream;
begin
  Result := False;
  Client := THTTPClient.Create;
  try
    // Minimal request body
    // Body := '{"model":"gpt-5.1-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":1,"temperature":0}';
    if UseMaxCompletionTokens('gpt-5.1-chat') then
    begin
      if ModelRequiresDefaultTemperature('gpt-5.1-chat') then
        Body := '{"model":"gpt-5.1-chat","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":1}'
      else
        Body := '{"model":"gpt-5.1-chat","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":1,"temperature":0}';
    end
    else
    begin
      if ModelRequiresDefaultTemperature('gpt-5.1-chat') then
        Body := '{"model":"gpt-5.1-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":1}'
      else
        Body := '{"model":"gpt-5.1-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":1,"temperature":0}';
    end;

    URL := UsedURL + CHAT_COMPLETIONS;
    Headers := [TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)];

    if EnableDebug then
    begin
      Writeln('--- PROBE POST (old code) ' + URL + ' ---');
      Writeln('Headers:');
      DumpHeaders(Headers);
      Writeln('Request JSON:');
      Writeln(PrettyJSON(Body));
      Writeln('--- End Request ---');
      Writeln;
    end;

    Stream := TStringStream.Create(Body, TEncoding.UTF8);
    try
      Resp := Client.Post(URL, Stream, nil, Headers);
    finally
      Stream.Free;
    end;

    if EnableDebug then
    begin
      Writeln('--- Response ---');
      Writeln(Format('Status: %d %s', [Resp.StatusCode, Resp.StatusText]));
      Writeln('Headers:');
      DumpHeaders(Resp.Headers);
      Writeln('Body:');
      Writeln(PrettyJSON(Resp.ContentAsString(TEncoding.UTF8)));
      Writeln('--- End Response ---');
      Writeln;
    end;

    Result := (Resp.StatusCode = 200);
    if not Result then
      Writeln('ProbeEndpoints: non-200 ' + IntToStr(Resp.StatusCode) +
        ' on ' + URL);
  finally
    Client.Free;
  end;
end;



function ProbeEndpoints(const AuthHeader: string; EnableDebug: Boolean;
  const BaseURL, ChatPath: string; const ModelName: string;
  const TimeoutMS: Integer): Boolean;   overload;
var
  Client: THTTPClient;
  URL: string;
  Headers: TNetHeaders;
  Body: string;
  Resp: IHTTPResponse;
  Stream: TStringStream;
begin
  Result := False;

  if AuthHeader.Trim = '' then
  begin
    if EnableDebug then
      Writeln('ProbeEndpoints: AuthHeader is empty');
    Exit(False);
  end;

  Client := THTTPClient.Create;
  try
    Client.ConnectionTimeout := TimeoutMS;
    Client.ResponseTimeout := TimeoutMS;

    // Build body based on model family rules [6]
    if UseMaxCompletionTokens(ModelName) then
    begin
      if ModelRequiresDefaultTemperature(ModelName) then
        Body := Format(
          '{"model":"%s","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":1024}',
          [ModelName])
      else
        Body := Format(
          '{"model":"%s","messages":[{"role":"user","content":"ping"}],"max_completion_tokens":1024,"temperature":0}',
          [ModelName]);
    end
    else
    begin
      if ModelRequiresDefaultTemperature(ModelName) then
        Body := Format(
          '{"model":"%s","messages":[{"role":"user","content":"ping"}],"max_tokens":1024}',
          [ModelName])
      else
        Body := Format(
          '{"model":"%s","messages":[{"role":"user","content":"ping"}],"max_tokens":1025,"temperature":0}',
          [ModelName]);
    end;

    // Use proper URL joining
    URL := BaseURL;
    if not URL.EndsWith('/') then
      URL := URL + '/';
    if ChatPath.StartsWith('/') then
      URL := URL + ChatPath.Substring(1)
    else
      URL := URL + ChatPath;

    Headers := [
      TNameValuePair.Create('Content-Type', 'application/json'),
      TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Authorization', AuthHeader)
    ];

    if EnableDebug then
    begin
      Writeln('--- PROBE POST (new code) ' + URL + ' ---');
      Writeln('Model: ' + ModelName);
      Writeln('Headers:');
      Writeln('Content-Type: application/json');
      Writeln('Authorization: ' + AuthHeader.Substring(0, Min(20, Length(AuthHeader))) + '...');
      Writeln('Request JSON:');
      Writeln(Body);
      Writeln('--- End Request ---');
      Writeln;
    end;

    Stream := TStringStream.Create(Body, TEncoding.UTF8);
    try
      Resp := Client.Post(URL, Stream, nil, Headers);
    finally
      Stream.Free;
    end;

    if EnableDebug then
    begin
      Writeln('--- Response ---');
      Writeln(Format('Status: %d %s', [Resp.StatusCode, Resp.StatusText]));
      Writeln('Body:');
      Writeln(Resp.ContentAsString(TEncoding.UTF8));
      Writeln('--- End Response ---');
      Writeln;
    end;

    // Accept any 2xx status, like your other probe code [7]
    Result := (Resp.StatusCode >= 200) and (Resp.StatusCode < 300);

    if not Result then
      Writeln(Format('ProbeEndpoints: HTTP %d on %s with model %s',
        [Resp.StatusCode, URL, ModelName]));

  finally
    Client.Free;
  end;
end;




end.
