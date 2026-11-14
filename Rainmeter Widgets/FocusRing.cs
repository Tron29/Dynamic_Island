using System;
using System.Windows;
using System.Windows.Media;

// Ratio is remaining time: a full circle at the start, empty at completion.
public sealed class FocusRing : FrameworkElement {
    public static readonly DependencyProperty RatioProperty = DependencyProperty.Register(
        "Ratio", typeof(double), typeof(FocusRing), new FrameworkPropertyMetadata(1.0, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Ratio { get { return (double)GetValue(RatioProperty); } set { SetValue(RatioProperty,value); } }
    public Brush RingBrush = Brushes.Silver;
    protected override void OnRender(DrawingContext dc) {
        double thickness = ActualWidth < 40 ? 2 : 3;
        double radius = Math.Max(0, Math.Min(ActualWidth,ActualHeight)/2 - thickness);
        Point center = new Point(ActualWidth/2,ActualHeight/2);
        dc.DrawEllipse(null,new Pen(new SolidColorBrush(Color.FromRgb(40,40,40)),thickness),center,radius,radius);
        double ratio = Math.Max(0, Math.Min(1,Ratio));
        Pen pen = new Pen(RingBrush,thickness); pen.StartLineCap=PenLineCap.Round; pen.EndLineCap=PenLineCap.Round;
        if(ratio>=1) { dc.DrawEllipse(null,pen,center,radius,radius); return; }
        if(ratio<=0) return;
        double angle=ratio*Math.PI*2-Math.PI/2;
        StreamGeometry geometry=new StreamGeometry();
        using(StreamGeometryContext path=geometry.Open()) {
            path.BeginFigure(new Point(center.X,center.Y-radius),false,false);
            path.ArcTo(new Point(center.X+Math.Cos(angle)*radius,center.Y+Math.Sin(angle)*radius),new Size(radius,radius),0,ratio>0.5,SweepDirection.Clockwise,true,false);
        }
        geometry.Freeze(); dc.DrawGeometry(null,pen,geometry);
    }
}
