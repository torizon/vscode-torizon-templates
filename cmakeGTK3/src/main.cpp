// Example based on https://www.gtk.org/docs/getting-started/hello-world
// Adapted to GTK 3

#include <gtk/gtk.h>
#include <iostream>

static void
print_hello(GtkWidget *widget,
            gpointer data)
{
    g_print("Hello Torizon World\n");
}

static void
activate(GtkApplication *app,
         gpointer user_data)
{
    GtkWidget *window;
    GtkWidget *button;

    window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Hello Torizon");
    gtk_window_set_default_size(GTK_WINDOW(window), 640, 480);
    gtk_window_fullscreen(GTK_WINDOW(window));

    button = gtk_button_new_with_label("Hello Torizon");
    g_signal_connect(button, "clicked", G_CALLBACK(print_hello), NULL);
    gtk_container_add(GTK_CONTAINER(window), button);

    gtk_widget_show_all(window);
}

int main(int argc,
         char **argv)
{
    GtkApplication *app;
    int status;

    app = gtk_application_new("org.gtk.example", G_APPLICATION_FLAGS_NONE);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);

    std::cout << "Hello Torizon!" << std::endl;

    status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);

    return status;
}
