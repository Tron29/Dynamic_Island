using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// Observe horizontal wheel input without activating the floating tool window.
// Precision touchpads emit these messages for two-finger horizontal scrolling.
public static class IslandTouchpad {
    delegate IntPtr HookProc(int code, IntPtr message, IntPtr data);
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X,Y; }
    [StructLayout(LayoutKind.Sequential)] struct MouseData { public Point Position; public uint Data,Flags,Time; public IntPtr Extra; }
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id,HookProc callback,IntPtr module,uint thread);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook,int code,IntPtr message,IntPtr data);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);
    static readonly HookProc Callback=OnMouse;
    static readonly Queue<int> Deltas=new Queue<int>();
    static IntPtr hook;
    static bool enabled;
    static int left,top,right,bottom;
    public static bool Start(){if(hook==IntPtr.Zero)hook=SetWindowsHookEx(14,Callback,GetModuleHandle(null),0);return hook!=IntPtr.Zero;}
    public static void Stop(){enabled=false;if(hook!=IntPtr.Zero){UnhookWindowsHookEx(hook);hook=IntPtr.Zero;}Deltas.Clear();}
    public static void Bounds(bool active,int x,int y,int width,int height){enabled=active;left=x;top=y;right=x+width;bottom=y+height;if(!active)Deltas.Clear();}
    public static int Pop(){return Deltas.Count>0?Deltas.Dequeue():0;}
    static IntPtr OnMouse(int code,IntPtr message,IntPtr data){
        if(code>=0 && enabled && message.ToInt64()==0x020E && (GetAsyncKeyState(1)&0x8000)==0){
            MouseData input=(MouseData)Marshal.PtrToStructure(data,typeof(MouseData));
            if(input.Position.X>=left && input.Position.X<right && input.Position.Y>=top && input.Position.Y<bottom){
                int delta=unchecked((short)(input.Data>>16));
                if(delta!=0 && Deltas.Count<64)Deltas.Enqueue(delta);
                return new IntPtr(1);
            }
        }
        return CallNextHookEx(hook,code,message,data);
    }
}
