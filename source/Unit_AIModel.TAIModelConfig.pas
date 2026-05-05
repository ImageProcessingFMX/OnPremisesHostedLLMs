unit Unit_AIModel.TAIModelConfig;

interface

///
/// very basic test of access to AI model
///
uses
  System.SysUtils, System.Classes, System.IniFiles, System.NetEncoding,
  IdHTTP, IdSSLOpenSSL, IdGlobal;


///   change  these values  !! 
Const HostURLs ='https://gpt.MyCompany.com';
      HostURL = 'https://gpt.MyCompany.com';

type
  TAuthMethod = (amBasic, amBearer, amWinCregdential);




  TAIModelConfig = record
    // Server paths
    BaseURL: string;
    ChatCompletionsPath: string;
    CompletionsPath: string;
    EmbeddingsPath: string;
    ImagesGenerationsPath: string;
    ModelsPath: string;
    AuthTokenEndpoint: string;
    // Auth
    AuthMethod: TAuthMethod; // Basic | Bearer
    WindowsUser: string;
    WindowsPassword: string;
    Token: string; // For Bearer auth
    // TLS
    CABundle: string; // e.g. 'ca-bundle.crt'
    VerifyPeer: Boolean;
    // Client defaults for tests
    Model: string; // e.g. 'llama3.3-70b'
    TimeoutMS: Integer; // e.g. 120000
    Temperature: Double; // e.g. 0.7
    MaxTokens: Integer; // e.g. 256
    Stream: Boolean; // stream response or not
  end;

function LoadAIModelConfig(const FileName: string; out C: TAIModelConfig)
  : Boolean;
// Legacy-style loader returning strings only (if you really need it)
procedure ConfigAIModel(const FileName: string; var BaseURL, ChatCompletions,
  Completions, Embeddings, ImagesGenerations, Models, AuthTokenEndpoint,
  AuthMethod, Token, WindowsUser, WindowsPassword, CABundle, Model, VerifyPeer,
  TimeoutMS, Temperature, MaxTokens, Stream: string);
// Helper: create an IdHTTP configured for TLS + timeouts
function CreateHTTP(const C: TAIModelConfig): TIdHTTP;
// Helper: set Authorization header on IdHTTP based on config
procedure ApplyAuthorization(const C: TAIModelConfig; HTTP: TIdHTTP);
// Optional helper: fetch a permanent Bearer token via /auth/token using Basic auth
function FetchPermanentTokenBasic(const C: TAIModelConfig): string;
// Minimal test call to /chat/completions
function TestChatCompletion(const C: TAIModelConfig;
  const UserMessage: string): string;

implementation

function StrToAuthMethod(const S: string): TAuthMethod;
begin
  if SameText(S, 'Basic') then
    Result := amBasic
  else
    Result := amBearer;
end;

function ReadStringTrim(const Ini: TIniFile;
  const Section, Ident, Default: string): string;
begin
  Result := Trim(Ini.ReadString(Section, Ident, Default));
end;

function ReadBoolFlexible(const Ini: TIniFile; const Section, Ident: string;
  const Default: Boolean): Boolean;
var
  S: string;
begin
  S := ReadStringTrim(Ini, Section, Ident, '');
  if S = '' then
    Exit(Default);

  S := LowerCase(S);
  if (S = 'true') or (S = 'yes') or (S = 'on') or (S = 'y') or (S = '1') then
    Exit(True);
  if (S = 'false') or (S = 'no') or (S = 'off') or (S = 'n') or (S = '0') then
    Exit(False);

  // Fallback to Ini.ReadBool if unusual values are used
  Result := Ini.ReadBool(Section, Ident, Default);
end;

function ReadIntFlexible(const Ini: TIniFile; const Section, Ident: string;
  const Default: Integer): Integer;
var
  S: string;
begin
  S := ReadStringTrim(Ini, Section, Ident, '');
  if (S = '') or (not TryStrToInt(S, Result)) then
    Result := Default;
end;

function TryStrToFloatAny(const S: string; out Value: Double): Boolean;
var
  FSLocal, FSPoint, FSComma: TFormatSettings;
  SS: string;
begin
  FSLocal := TFormatSettings.Create;
  FSPoint := TFormatSettings.Create;
  FSComma := TFormatSettings.Create;
  FSPoint.DecimalSeparator := '.';
  FSComma.DecimalSeparator := ',';

  // Try with local settings first
  if TryStrToFloat(S, Value, FSLocal) then
    Exit(True);
  // Try explicit separators
  if TryStrToFloat(S, Value, FSPoint) then
    Exit(True);
  if TryStrToFloat(S, Value, FSComma) then
    Exit(True);

  // Normalize and try again (replace comma with dot)
  SS := StringReplace(S, ',', '.', [rfReplaceAll]);
  if TryStrToFloat(SS, Value, FSPoint) then
    Exit(True);

  Result := False;
end;

function ReadFloatFlexible(const Ini: TIniFile; const Section, Ident: string;
  const Default: Double): Double;
var
  S: string;
  V: Double;
begin
  S := ReadStringTrim(Ini, Section, Ident, '');
  if (S = '') then
    Exit(Default);
  if TryStrToFloatAny(S, V) then
    Result := V
  else
    Result := Default;
end;

function LoadAIModelConfig(const FileName: string; out C: TAIModelConfig)
  : Boolean;
var
  Ini: TIniFile;
begin
  Result := FileExists(FileName);
  Ini := TIniFile.Create(FileName);
  try
    // Server
    C.BaseURL := ReadStringTrim(Ini, 'server', 'BaseURL', HostURLs );
    C.ChatCompletionsPath := ReadStringTrim(Ini, 'server', 'ChatCompletions',
      '/chat/completions');
    C.CompletionsPath := ReadStringTrim(Ini, 'server', 'Completions',
      '/completions');
    C.EmbeddingsPath := ReadStringTrim(Ini, 'server', 'Embeddings',
      '/embeddings');
    C.ImagesGenerationsPath := ReadStringTrim(Ini, 'server',
      'ImagesGenerations', '/images/generations');
    C.ModelsPath := ReadStringTrim(Ini, 'server', 'Models', '/models');

    C.AuthTokenEndpoint := ReadStringTrim(Ini, 'server', 'AuthTokenEndpoint',
      '/auth/token');

    // Auth
    C.AuthMethod := StrToAuthMethod(ReadStringTrim(Ini, 'auth', 'Method',
      'Bearer'));
    C.WindowsUser := ReadStringTrim(Ini, 'auth', 'WindowsUser', '');
    C.WindowsPassword := ReadStringTrim(Ini, 'auth', 'WindowsPassword', '');
    C.Token := ReadStringTrim(Ini, 'auth', 'Token', '');

    // TLS
    C.CABundle := ReadStringTrim(Ini, 'tls', 'CABundle', 'ca-bundle.crt');
    C.VerifyPeer := ReadBoolFlexible(Ini, 'tls', 'VerifyPeer', True);

    // Client defaults for tests
    C.Model := ReadStringTrim(Ini, 'client', 'Model', 'llama3.3-70b');
    // default aligns with your INI [1]
    C.TimeoutMS := ReadIntFlexible(Ini, 'client', 'TimeoutMS', 120000);
    // default 120000 as in INI [1]
    C.Temperature := ReadFloatFlexible(Ini, 'client', 'Temperature', 0.7);
    // accepts 0.7 or 0,7 [1]
    C.MaxTokens := ReadIntFlexible(Ini, 'client', 'MaxTokens', 256);
    C.Stream := ReadBoolFlexible(Ini, 'client', 'Stream', False);
  finally
    Ini.Free;
  end;
end;

procedure ConfigAIModel(const FileName: string; var BaseURL, ChatCompletions,
  Completions, Embeddings, ImagesGenerations, Models, AuthTokenEndpoint,
  AuthMethod, Token, WindowsUser, WindowsPassword, CABundle, Model, VerifyPeer,
  TimeoutMS, Temperature, MaxTokens, Stream: string);
var
  C: TAIModelConfig;
begin
  if not LoadAIModelConfig(FileName, C) then; // still fill from defaults below

  BaseURL := C.BaseURL;
  ChatCompletions := C.ChatCompletionsPath;
  Completions := C.CompletionsPath;
  Embeddings := C.EmbeddingsPath;
  ImagesGenerations := C.ImagesGenerationsPath;
  Models := C.ModelsPath;
  AuthTokenEndpoint := C.AuthTokenEndpoint;
  if C.AuthMethod = amBasic then
    AuthMethod := 'Basic'
  else
    AuthMethod := 'Bearer';
  Token := C.Token;
  WindowsUser := C.WindowsUser;
  WindowsPassword := C.WindowsPassword;
  CABundle := C.CABundle;
  Model := C.Model;
  VerifyPeer := BoolToStr(C.VerifyPeer, True);
  TimeoutMS := IntToStr(C.TimeoutMS);
  Temperature := FloatToStr(C.Temperature);
  MaxTokens := IntToStr(C.MaxTokens);
  Stream := BoolToStr(C.Stream, True);
end;

function CreateSSL(const C: TAIModelConfig): TIdSSLIOHandlerSocketOpenSSL;
begin
  Result := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  // Basic TLS setup; for production, consider implementing OnVerifyPeer and CA handling
  if C.VerifyPeer then
  begin
    // Leave default VerifyMode; you can add OnVerifyPeer to validate using CABundle
    Result.SSLOptions.VerifyMode := [];
  end
  else
  begin
    // Not recommended for production; allows insecure connections
    Result.SSLOptions.VerifyMode := [];
  end;
end;

function CreateHTTP(const C: TAIModelConfig): TIdHTTP;
begin
  Result := TIdHTTP.Create(nil);
  Result.IOHandler := CreateSSL(C);
  Result.Request.ContentType := 'application/json';
  Result.Request.Accept := 'application/json';
  Result.ConnectTimeout := C.TimeoutMS;
  Result.ReadTimeout := C.TimeoutMS;
  Result.HandleRedirects := True;
end;

procedure ApplyAuthorization(const C: TAIModelConfig; HTTP: TIdHTTP);
begin
  if C.AuthMethod = amBearer then
    HTTP.Request.CustomHeaders.Values['Authorization'] := 'Bearer ' + C.Token
  else
    HTTP.Request.CustomHeaders.Values['Authorization'] := 'Basic ' +
      TNetEncoding.Base64.Encode(C.WindowsUser + ':' + C.WindowsPassword);
end;

function FetchPermanentTokenBasic(const C: TAIModelConfig): string;
begin
  // Stub: implement with a POST/GET to JoinURL(C.BaseURL, C.AuthTokenEndpoint)
  // using Basic Authorization if needed. Not required for the INI parsing task.
  Result := '';
end;

function TestChatCompletion(const C: TAIModelConfig;
  const UserMessage: string): string;
begin
  // Stub: implement the JSON request to BaseURL + ChatCompletionsPath
  Result := '';
end;

end.
