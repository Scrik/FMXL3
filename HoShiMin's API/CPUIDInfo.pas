unit CPUIDInfo;

interface

type
  TSSESupport = record
    SSE1  : Boolean;
    SSE2  : Boolean;
    SSE3  : Boolean;
    SSSE3 : Boolean;
    SSE41 : Boolean;
    SSE42 : Boolean;
  end;

  TCPUFeatures = record
    MMX    : Boolean;
    SSE    : TSSESupport;
    RDTSCP : Boolean;
    AVX    : Boolean;
    AES    : Boolean;
    FMA    : Boolean;
  end;

  TCPUInfo = record
    CPUFeatures: TCPUFeatures;
  end;

type
  TCPUIDInfo = packed record
    EAX: LongWord;
    EBX: LongWord;
    ECX: LongWord;
    EDX: LongWord;
  end;

procedure CPUID(FunctionNumber: LongWord; out CPUIDInfo: TCPUIDInfo); register;
procedure GetCPUInfo(out CPUInfo: TCPUInfo);

var
  CPUInfo: TCPUInfo;

implementation

const
// Номера битов в регистрах, возвращаемых от CPUID:

// CPUID($00000001):
  // ECX:
    bnSSE3  = 0;
    bnSSSE3 = 9;
    bnFMA   = 12;
    bnSSE41 = 19;
    bnSSE42 = 20;
    bnAES   = 25;
    bnAVX   = 28;

  // EDX:
    bnMMX  = 23;
    bnSSE1 = 25;
    bnSSE2 = 26;

// CPUID($80000001):
  //EDX:
    bnRDTSCP = 27;

procedure CPUID(FunctionNumber: LongWord; out CPUIDInfo: TCPUIDInfo); register;
asm
{$IFDEF CPUX64}
  push rax
  push rbx
  push rcx
  push rdx
  push rdi

  xor rax, rax
  mov eax, ecx
  mov rdi, rdx
{$ELSE}
  push eax
  push ebx
  push ecx
  push edx
  push edi

  mov edi, edx
{$ENDIF}

  cpuid

{$IFDEF CPUX64}
  mov [rdi + 0 ], eax
  mov [rdi + 4 ], ebx
  mov [rdi + 8 ], ecx
  mov [rdi + 12], edx

  pop rdi
  pop rdx
  pop rcx
  pop rbx
  pop rax
{$ELSE}
  mov [edi + 0 ], eax
  mov [edi + 4 ], ebx
  mov [edi + 8 ], ecx
  mov [edi + 12], edx

  pop edi
  pop edx
  pop ecx
  pop ebx
  pop eax
{$ENDIF}
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function IsBitSet(Value: LongWord; BitNumber: Integer): LongBool; inline;
begin
  Result := LongBool(Value and (1 shl BitNumber));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure GetCPUInfo(out CPUInfo: TCPUInfo);
var
  CPUIDInfo: TCPUIDInfo;
begin
  CPUID($00000001, CPUIDInfo);

  CPUInfo.CPUFeatures.SSE.SSE3  := IsBitSet(CPUIDInfo.ECX, bnSSE3);
  CPUInfo.CPUFeatures.SSE.SSSE3 := IsBitSet(CPUIDInfo.ECX, bnSSSE3);
  CPUInfo.CPUFeatures.FMA       := IsBitSet(CPUIDInfo.ECX, bnFMA);
  CPUInfo.CPUFeatures.SSE.SSE41 := IsBitSet(CPUIDInfo.ECX, bnSSE41);
  CPUInfo.CPUFeatures.SSE.SSE42 := IsBitSet(CPUIDInfo.ECX, bnSSE42);
  CPUInfo.CPUFeatures.AES       := IsBitSet(CPUIDInfo.ECX, bnAES);
  CPUInfo.CPUFeatures.AVX       := IsBitSet(CPUIDInfo.ECX, bnAVX);

  CPUInfo.CPUFeatures.MMX      := IsBitSet(CPUIDInfo.EDX, bnMMX);
  CPUInfo.CPUFeatures.SSE.SSE1 := IsBitSet(CPUIDInfo.EDX, bnSSE1);
  CPUInfo.CPUFeatures.SSE.SSE2 := IsBitSet(CPUIDInfo.EDX, bnSSE2);

  CPUID($80000001, CPUIDInfo);

  CPUInfo.CPUFeatures.RDTSCP := IsBitSet(CPUIDInfo.EDX, bnRDTSCP);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

initialization
  GetCPUInfo(CPUInfo);

end.
