-- Read-only diagnostics. Original known-client execution is not capability-gated.
SlashCmdList=SlashCmdList or {}
SLASH_MQOL_BOOT1='/mqolboot'
SlashCmdList.MQOL_BOOT=function()
    local ci=mQoL_VersionDetection and mQoL_VersionDetection.clientInfo or {}
    print('[mQoL] v1.3.0 / build 309 / AM-R3')
    print('Identity: '..tostring(ci.tree)..' / '..tostring(ci.versionKey)..' | TOC '..tostring(ci.tocversion)..' | client build '..tostring(ci.build))
    print('UI: SHARED ORIGINAL HUB (no alternate Auto UI)')
    print('Hub: '..((mQoL_Hub and type(mQoL_Hub.ToggleMainPanel)=='function') and 'defined' or 'missing'))
    print('Registry: '..((mQoL_Modules and type(mQoL_Modules.ShouldLoadModule)=='function') and 'original shared registry' or 'missing'))
    if mQoL_Auto then
        print('Auto: availability checks and per-operation adapters; partial is NOT a module runtime gate.')
        print('Route: SHARED_UI | diagnostics: /mqolauto [refresh]')
        if mQoL_Auto.minimapUnavailable then print(mQoL_Auto.minimapUnavailable) end
        for key,err in pairs(mQoL_Auto.errors or {}) do print('ERROR '..key..': '..err) end
    else
        print('Route: BASELINE (known client) | Auto checks: NOT INSTALLED')
    end
end
if not mQoL_Auto then
    SLASH_MQOL_AUTO1='/mqolauto'
    SlashCmdList.MQOL_AUTO=function()
        SlashCmdList.MQOL_BOOT()
        print('This client retains baseline availability. No Auto refresh is applied.')
    end
end
