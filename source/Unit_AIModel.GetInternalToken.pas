unit Unit_AIModel.GetInternalToken;

///
///   very basic test  of access to AI model
///   V 2 : 25.04.2025

interface


uses  Unit_AIModel.TAIModelConfig,
      Unit_AIModel.Helper;

function GetCompanyInternalToken: string; overload;

function GetCompanyInternalToken(const TimeoutMS: Integer;
  const BaseURL, AuthEndpoint: string): string; overload;



implementation

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.NetEncoding,
  System.JSON,
  System.IniFiles,
  System.IOUtils,
  System.RegularExpressions;



function ExtractTokenFromJson(const S: string): string;
var
  JsonVal: TJSONValue;
  Obj: TJSONObject;
  Tok: string;
begin
  Result := '';
  JsonVal := TJSONObject.ParseJSONValue(S);
  try
    if JsonVal is TJSONObject then
    begin
      Obj := TJSONObject(JsonVal);
      if Obj.TryGetValue<string>('token', Tok) then
        Exit(Tok);
      if Obj.TryGetValue<string>('access_token', Tok) then
        Exit(Tok);
    end
    else if JsonVal is TJSONString then
      Exit(TJSONString(JsonVal).Value);
  finally
    JsonVal.Free;
  end;
end;





function ExtractTokenFromHTML(const Html: string): string;
var
  M: TMatch;
  Inner: string;
begin
  Result := '';
  // Capture content inside <pre>…</pre>, non-greedy
  // Fixed: [^>]* instead of [^>]
  M := TRegEx.Match(Html, '<pre[^>]*>([\s\S]*?)</pre>', [roIgnoreCase]);
  if not M.Success then
  begin
    // Fallback: try whole body as JSON
    Result := ExtractTokenFromJson(Html);
    Exit;
  end;

  // First capture group contains the inner text
  Inner := M.Groups.Item[1].Value;  // Fixed: Groups.Item[1] to get first capture group

  // Try JSON first
  Result := ExtractTokenFromJson(Inner);
  if Result = '' then
    Result := Inner.Trim;
end;



function GetCompanyInternalToken(const TimeoutMS: Integer;
  const BaseURL, AuthEndpoint: string): string;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Html, URL: string;
  TMS: Integer;
begin

 //
 //  expected result:= 'qErBlVYYx.....  RlQbF4ug4oB0N162bG2g';
 //

  // Resolve parameters; if missing/invalid, load from INI/defaults

  TMS := TimeoutMS;
  if   (BaseURL ='') or  (TMS <= 0) then exit;


  URL := JoinURL (BaseURL, AuthEndpoint) ;

  Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := TMS;
    Http.ResponseTimeout := TMS;
    Http.UserAgent := 'Delphi-HTTPClient/1.0';

    try
      Resp := Http.Get(URL);
      if (Resp <> nil) and (Resp.StatusCode = 200) then
      begin
        Html := Resp.ContentAsString(TEncoding.UTF8);
        // Result := ExtractTokenFromHTML(Html);
        Result := HtmL;
      end
      else
        Result := '';
    except
      on E: Exception do
        Result := '';
    end;
  finally
    Http.Free;
  end;
end;

function GetCompanyInternalToken: string;
begin
  // Delegate to the parameterized version, which reads defaults from INI if needed
  Result := GetCompanyInternalToken(9000, HostURL,  '/auth/token');
end;

end.
