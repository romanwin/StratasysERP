create or replace and compile java source named xxdbjavautil as
import java.io.*;


public class XXDBJavaUtil
{
  public XXDBJavaUtil()
  {
  }

  public static void main(String[] args)
  {
    XXDBJavaUtil xXDBJavaUtil = new XXDBJavaUtil();
    String s=xXDBJavaUtil.getDirFiles("c:/");
  }

  public static String getDirFiles(String pDir)
  {
    File folder = new File(pDir);
    File[] listOfFiles = folder.listFiles();
    String fileList=null;

    for (int i = 0; i < listOfFiles.length; i++) {
      if (listOfFiles[i].isFile()) {
        System.out.println("File " + listOfFiles[i].getName());
        fileList=fileList+","+listOfFiles[i].getName();
      } else if (listOfFiles[i].isDirectory()) {
        System.out.println("Directory " + listOfFiles[i].getName());

      }

    }
    return fileList;
  }

  public static String exeHostCMD(String p_cmd)
{
String line=null;
     try {
     //"ypcat hosts | grep -w pr_mis | awk '{print $1}'";
//String[] cmd = {"/bin/sh", "-c", p_cmd};
String[] cmd = {"/bin/sh",p_cmd};
     Process p = Runtime.getRuntime().exec
       (cmd);
     BufferedReader input =
       new BufferedReader
         (new InputStreamReader(p.getInputStream()));
           while ((line = input.readLine()) != null) {
                      System.out.println(line);
                  }
       System.out.println(line);
     input.close();
     }
    catch (Exception err) {
   err.printStackTrace();
   return "E:Cmd="+p_cmd+" Trace="+err.toString();
     }
return line;
}
};
/
