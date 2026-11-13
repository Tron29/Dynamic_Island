using System;
using System.Runtime.InteropServices;
// Read-only Windows playback endpoint metering; no microphone or recording.
public sealed class IslandAudioMeter {
    IMeter meter;
    IVolume volume;
    DateTime retry;
    public float Read() {
        try {
            if (meter == null || DateTime.UtcNow > retry) {
                if (meter != null) Marshal.ReleaseComObject(meter);
                var enumerator = (IDevices)new Devices();
                IDevice device;
                Marshal.ThrowExceptionForHR(enumerator.Default(0, 1, out device));
                object value; var id=typeof(IMeter).GUID;
                Marshal.ThrowExceptionForHR(device.Activate(ref id,23,IntPtr.Zero,out value));
                meter=(IMeter)value;
                if(volume!=null) Marshal.ReleaseComObject(volume);
                id=typeof(IVolume).GUID;
                Marshal.ThrowExceptionForHR(device.Activate(ref id,23,IntPtr.Zero,out value));
                volume=(IVolume)value;
                Marshal.ReleaseComObject(device); Marshal.ReleaseComObject(enumerator);
                retry=DateTime.UtcNow.AddSeconds(3);
            }
            float peak; Marshal.ThrowExceptionForHR(meter.Peak(out peak));             float db; bool muted;
            Marshal.ThrowExceptionForHR(volume.GetMasterVolumeLevel(out db));
            Marshal.ThrowExceptionForHR(volume.GetMute(out muted));
            return muted ? 0 : (float)(peak * Math.Pow(10, db/20.0));
        } catch {meter=null; return 0;}
    }
    [ComImport,Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IVolume {
        [PreserveSig] int Register(IntPtr callback);
        [PreserveSig] int Unregister(IntPtr callback);
        [PreserveSig] int GetChannelCount(out uint count);
        [PreserveSig] int SetMasterVolumeLevel(float db,IntPtr context);
        [PreserveSig] int SetMasterVolumeLevelScalar(float value,IntPtr context);
        [PreserveSig] int GetMasterVolumeLevel(out float db);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float value);
        [PreserveSig] int SetChannelVolumeLevel(uint channel,float db,IntPtr context);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint channel,float value,IntPtr context);
        [PreserveSig] int GetChannelVolumeLevel(uint channel,out float db);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint channel,out float value);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute,IntPtr context);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }
    [ComImport,Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class Devices {}
    [ComImport,Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDevices {
        [PreserveSig] int Enum(int flow,uint mask,out IntPtr devices);
        [PreserveSig] int Default(int flow,int role,out IDevice device);
    }
    [ComImport,Guid("D666063F-1587-4E43-81F1-B948E807363F"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDevice {
        [PreserveSig] int Activate(ref Guid id,int context,IntPtr args,[MarshalAs(UnmanagedType.IUnknown)] out object value);
    }
    [ComImport,Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IMeter {
        [PreserveSig] int Peak(out float value);
        [PreserveSig] int Count(out uint count);
        [PreserveSig] int Channels(uint count,[Out,MarshalAs(UnmanagedType.LPArray,SizeParamIndex=0)] float[] values);
        [PreserveSig] int Support(out uint mask);
    }
}
