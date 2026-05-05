program GenAI_HostedInternal;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.NetEncoding,
  System.JSON,
  ///
  ///    Units  for testing, connection and evaluation
  ///    of local hosted LLM
  ///
  Unit_AIModel.Communication in 'Unit_AIModel.Communication.pas',
  Unit_AIModel.GetInternalToken in 'Unit_AIModel.GetInternalToken.pas',
  Unit_AIModel.Helper in 'Unit_AIModel.Helper.pas',
  Unit_AIModel.TAIModelConfig in 'Unit_AIModel.TAIModelConfig.pas',
  Unit_AIModel.Probing in 'Unit_AIModel.Probing.pas';

const
  AIParameterFile ='C:\repos\MyFolder\Config_AIModels.ini';

var
  Choice: string;
  Token: string;
  WinUser, WinPass: string;
  Question: string;
  AuthHeader: string;
  Answer: string;
  EnableDebug: Boolean;
  yn: string;
  AIModelConfig: TAIModelConfig;

begin

  if not LoadAIModelConfig(AIParameterFile, AIModelConfig ) then
  begin
    ///
    /// need to set some default parameters !
    ///

    AIModelConfig.BaseURL := HostURL;
    AIModelConfig.ChatCompletionsPath := HostURL + CHAT_COMPLETIONS;
    AIModelConfig.CompletionsPath := HostURL + COMPLETIONS;
    AIModelConfig.Model := 'gpt-5.3-chat';
    AIModelConfig.MaxTokens := 2024;
    AIModelConfig.TimeoutMS := 1000;

  end;


  // Use a known locally hosted model, e.g.,

  Writeln('LLM gateway console test (Access locally hosted AI models)');
  Writeln('ParameterFile  : ' + AIParameterFile);
  Writeln('OpenAI base    : ' + HostURL + CHAT_COMPLETIONS);
  Writeln('Token endpoint : ' + HostURL + AUTH_TOKEN_ENDPOINT);
  Writeln('Model          : ' + AIModelConfig.Model);
  Writeln('Model MaxToken : ' + AIModelConfig.MaxTokens.ToString);

  try
    Writeln;
    Write('Enable debug prints (y/N)? ');

    Readln(yn);
    EnableDebug := SameText(Trim(yn), 'y');

    Writeln('Select auth method:');
    Writeln(' 1) Bearer (paste SSO token) [recommended]');
    Writeln(' 2) Basic (fetch permanent token via /auth/token)');
    Writeln(' 3) Token from URL (GetComapanyInternalToken)');
    Writeln(' 4) Token from config file ( needs frequent updates!)');
    Write('Enter 1, 2 or 3: ');
    Readln(Choice);
    Choice := Choice.Trim;


    if Choice = '1' then
    begin
      Write('Paste your Bearer token (SSO): ');
      Readln(Token);
      if Token.IsEmpty then
      begin
        Writeln('No token provided.');
        Exit;
      end;
      AuthHeader := 'Bearer ' + Token;
    end
    else if Choice = '2' then
    begin
      Writeln('Enter Windows service account (DOMAIN\user or user@domain) and password:');
      Write('User: ');
      Readln(WinUser);
      Write('Pass: ');
      Readln(WinPass);
      Token := GetPermanentTokenViaBasic(AIModelConfig.BaseURL, WinUser, WinPass, EnableDebug);
      if Token.IsEmpty then
      begin
        Writeln('Failed to obtain token via Basic auth.');
        Exit;
      end;
      Writeln('Token obtained successfully.');
      AuthHeader := 'Bearer ' + Token;
    end
    else if Choice = '3' then
    begin
      // New option: Obtain token via URL 
      Token := GetCompanyInternalToken;
      if Token.IsEmpty then
      begin
        Writeln('Failed to obtain token via URL (GetCompanyToken returned empty).');
        Exit;
      end;
      Writeln('Token obtained successfully from URL.');
      Writeln (Token);
      AuthHeader := 'Bearer ' + Token;
    end
        else if Choice = '4' then
    begin
         Token :=  AIModelConfig.Token;
               if Token.IsEmpty then
      begin
        Writeln('Failed to obtain token via config file.');
        Exit;
      end;
      Writeln('Token obtained successfully from file.');
      Writeln (Token);
      AuthHeader := 'Bearer ' + Token;
    end
    else
    begin
      Writeln('Invalid choice. Exiting.');
      Exit;
    end;

    // Optional: check models endpoint to validate base and token
    if not FetchModels(AIModelConfig.BaseURL, AuthHeader, EnableDebug) then
    begin
      Writeln('Models listing failed. Will still try chat, but base/token may be wrong.');
    end;

    // Optional: probe chat endpoint with a tiny request
    if not ProbeEndpoints(AIModelConfig.BaseURL, AuthHeader, EnableDebug) then
    begin
      Writeln('Probe POST failed; likely wrong path or model. Verify OPENAI_BASE or model.');
    end;



    // After loading config [1]
if not ProbeEndpoints(AuthHeader, EnableDebug,
                      AIModelConfig.BaseURL,           // from [1]
                      AIModelConfig.ChatCompletionsPath, // from [1]
                      AIModelConfig.Model,             // 'gpt-5.3-chat' from [1]
                      AIModelConfig.TimeoutMS) then    // from [1]
begin
  Writeln('Probe POST failed; likely wrong path or model. Verify config.');
end;







    ///
    /// 3 line with AI model execution
    ///

    Question :=
      'Hello! Could you please explain circuit reverse engineeringt to me in 10 words ?';

        Question :=
      'write a short delphi demo program ?';



    Writeln('-> Question:' +  Question )  ;

    Answer := PostChatCompletions(AuthHeader,  Question, EnableDebug, AIModelConfig);

    Writeln('<- Answer:' + Answer);

    ///
    /// done
    ///
  except
    on E: Exception do
      Writeln('Error: ' + E.ClassName + ' - ' + E.Message);
  end;

  Writeln('Press ENTER to exit.');
  Readln;

end.
