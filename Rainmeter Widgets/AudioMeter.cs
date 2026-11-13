using System;
using System.Runtime.InteropServices;
// Read-only Windows playback endpoint metering; no microphone or recording.
public sealed class IslandAudioMeter {
    public float RawPeak { get; private set; }
    public float VolumeDb { get; private set; }
    public string LastError { get; private set; }
    sealed class Output { public IMeter Meter; public IVolume Volume; }
    System.Collections.Generic.List<Output> outputs=new System.Collections.Generic.List<Output>();
    DateTime retry;
    public float Read() {
      try {
        if(DateTime.UtcNow>retry){
          foreach(var o in outputs){Marshal.ReleaseComObject(o.Meter);Marshal.ReleaseComObject(o.Volume);} outputs.Clear();
          var enumerator=(IDevices)new Devices();IDeviceCollection collection;
          Marshal.ThrowExceptionForHR(enumerator.Enum(0,1,out collection));uint count;collection.Count(out count);
          for(uint i=0;i<count;i++){
            IDevice device;collection.Item(i,out device);
            try{object m,v;var id=typeof(IMeter).GUID;
              Marshal.ThrowExceptionForHR(device.Activate(ref id,23,IntPtr.Zero,out m));id=typeof(IVolume).GUID;
              Marshal.ThrowExceptionForHR(device.Activate(ref id,23,IntPtr.Zero,out v));outputs.Add(new Output{Meter=(IMeter)m,Volume=(IVolume)v});
            }catch{}finally{Marshal.ReleaseComObject(device);}
          }
          Marshal.ReleaseComObject(collection);Marshal.ReleaseComObject(enumerator);retry=DateTime.UtcNow.AddSeconds(3);
        }
        float result=0;RawPeak=0;
        foreach(var output in outputs){float peak,db;bool muted;
          if(output.Meter.Peak(out peak)<0 || output.Volume.GetMasterVolumeLevel(out db)<0 || output.Volume.GetMute(out muted)<0)continue;
          float adjusted=muted?0:(float)(peak*Math.Pow(10,db/20.0));
          if(adjusted>result){result=adjusted;RawPeak=peak;VolumeDb=db;}
        }
        LastError=null;return result;
      }catch(Exception e){LastError=e.Message;retry=DateTime.MinValue;return 0;}
    }
    [ComImport,Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface IDeviceCollection{
      [PreserveSig]int Count(out uint count);
      [PreserveSig]int Item(uint index,out IDevice device);
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
        [PreserveSig] int Enum(int flow,uint mask,out IDeviceCollection devices);
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
